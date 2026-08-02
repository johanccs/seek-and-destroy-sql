using System.Text.Json;
using SqlPerf.Api.Models;
using SqlPerf.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<LessonCatalog>();
builder.Services.AddSingleton<TrackRegistry>();
builder.Services.AddSingleton<SqlExecutor>();
builder.Services.AddSingleton<SchemaReader>();
builder.Services.AddSingleton<ConcurrencyRunner>();
builder.Services.AddSingleton<ProgressStore>();
builder.Services.AddSingleton<DockerOps>();
builder.Services.AddSingleton<TutorHistoryStore>();
builder.Services.AddSingleton<TutorService>();
builder.Services.AddHttpClient("openrouter");
builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    o.SerializerOptions.DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.Never;
});

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
app.UseCors();

// Warm up the progress store in the background so the first request isn't slow
// (non-fatal if the DB is still cold).
_ = Task.Run(async () =>
{
    try { await app.Services.GetRequiredService<ProgressStore>().EnsureReadyAsync(); }
    catch (Exception ex) { app.Logger.LogWarning(ex, "Progress-store warmup failed (SQL not ready yet?)"); }
});

// ---- Health ----
app.MapGet("/api/health", async (LessonCatalog cat, ProgressStore progress) =>
{
    string sql = "disconnected";
    try { await progress.EnsureReadyAsync(); sql = "connected"; } catch { }
    return Results.Json(new HealthDto("ok", sql, cat.Count));
});

// ---- Curriculum ----

// track is optional and defaults to the performance track: /api/levels predates
// tracks, so an un-parameterised call must keep returning what it always did.
app.MapGet("/api/levels", async (string? track, LessonCatalog cat, ProgressStore progress,
    TrackRegistry tracks) =>
{
    var t = tracks.Resolve(track);
    var prog = await progress.GetAllAsync();
    var levels = t.Levels.Select(lt =>
    {
        var lessons = cat.ForTrack(t.Key)
            .Where(l => string.Equals(l.Manifest.Level, lt.Key, StringComparison.OrdinalIgnoreCase))
            .OrderBy(l => l.Manifest.Order)
            .Select(l =>
            {
                var p = prog.GetValueOrDefault(l.Manifest.Id) ?? new ProgressDto(false, null, null);
                return new LessonSummaryDto(l.Manifest.Id, l.Manifest.Order, l.Manifest.Title,
                    l.Manifest.Topics, l.Manifest.EstimatedMinutes, l.IsConcurrency,
                    p.Solved, p.BestLogicalReads, p.BestDurationMs, l.Manifest.Description,
                    l.Manifest.AzureUnsupported, l.Manifest.Track, l.Manifest.Kind);
            }).ToList();
        return new LevelDto(lt.Key, lt.Title, lt.Description, lessons);
    }).ToList();
    return Results.Json(levels);
});

app.MapGet("/api/tracks", async (LessonCatalog cat, ProgressStore progress, TrackRegistry tracks) =>
{
    var prog = await progress.GetAllAsync();
    var dtos = tracks.All.Select(t =>
    {
        var lessons = cat.ForTrack(t.Key).ToList();
        int solved = lessons.Count(l => prog.GetValueOrDefault(l.Manifest.Id)?.Solved == true);
        return new TrackDto(t.Key, t.Title, t.Description, lessons.Count, solved);
    }).ToList();
    return Results.Json(dtos);
});

app.MapGet("/api/lessons/{id}", async (string id, LessonCatalog cat, ProgressStore progress) =>
{
    var l = cat.Get(id);
    if (l is null) return Results.NotFound();
    var p = await progress.GetAsync(id);
    object? interleaving = l.Manifest.Interleaving is null ? null : new
    {
        description = l.Manifest.Interleaving.Description,
        sessions = l.Manifest.Interleaving.Sessions,
        resolveConditions = l.Manifest.Interleaving.ResolveConditions,
    };
    return Results.Json(new LessonDetailDto(l.Manifest.Id, l.Manifest.Level, l.Manifest.Title,
        l.Manifest.Topics, l.Manifest.EstimatedMinutes, l.Manifest.Narrative, l.Manifest.StartingQuery,
        l.Manifest.Hints, l.IsConcurrency, interleaving, p, l.Manifest.Description,
        l.Manifest.AzureUnsupported, l.Manifest.Track, l.Manifest.Kind));
});

app.MapGet("/api/lessons/{id}/solution", (string id, LessonCatalog cat) =>
{
    var l = cat.Get(id);
    return l is null ? Results.NotFound() : Results.Json(new SolutionDto(l.SolutionSql));
});

// ---- Table/column/index metadata for the lesson's schema ----
// Separate endpoint and separate connection from /run on purpose: see SchemaReader.
app.MapGet("/api/lessons/{id}/schema", async (string id, LessonCatalog cat,
    SqlExecutor exec, SchemaReader schema) =>
{
    var l = cat.Get(id);
    if (l is null) return Results.NotFound();
    if (!await exec.SchemaExistsAsync(l.Database))
        return Results.Json(new SchemaDto(l.Database, false, new List<SchemaTableDto>()));
    return Results.Json(await schema.ReadAsync(l.Database));
});

// ---- Run a query ----
app.MapPost("/api/lessons/{id}/run", async (string id, RunRequest req, LessonCatalog cat,
    SqlExecutor exec, ProgressStore progress) =>
{
    var l = cat.Get(id);
    if (l is null) return Results.NotFound();

    var art = await exec.RunAsync(l, req.Sql ?? "");
    if (!art.Success)
        return Results.Json(new RunResult(false, art.Error, art.ResultSets, art.Stats, null,
            art.Messages, null, null));

    var parsed = PlanParser.Parse(art.PlanXml);

    // Scratch run: execute and report, but do not grade and do not touch progress.
    // GetBaselineAsync is skipped too — it is only an input to grading.
    if (!req.Graded)
        return Results.Json(new RunResult(true, null, art.ResultSets, art.Stats, parsed?.Dto,
            art.Messages, null, await progress.GetAsync(id)));

    var baseline = await exec.GetBaselineAsync(l);
    var eval = Evaluator.EvaluateQuery(l.Manifest.PassConditions, parsed?.Dto,
        parsed?.RootCost ?? 0, art.Stats, art.ResultSets, baseline);

    ProgressDto prog;
    if (eval.Passed)
        prog = await progress.RecordSolveAsync(id, art.Stats?.TotalLogicalReads, art.Stats?.ElapsedTimeMs);
    else
        prog = await progress.GetAsync(id);

    return Results.Json(new RunResult(true, null, art.ResultSets, art.Stats, parsed?.Dto,
        art.Messages, eval, prog));
});

// ---- Run a concurrency interleaving ----
app.MapPost("/api/lessons/{id}/run-concurrency", async (string id, ConcurrencyRunRequest req,
    LessonCatalog cat, SqlExecutor exec, ConcurrencyRunner runner, ProgressStore progress) =>
{
    var l = cat.Get(id);
    if (l is null) return Results.NotFound();
    if (!l.IsConcurrency) return Results.BadRequest(new { error = "Not a concurrency lesson" });

    await exec.EnsureSeededAsync(l);
    var sessions = req.Sessions ?? l.Manifest.Interleaving!.Sessions;
    var result = await runner.RunAsync(l.Database, sessions);

    var eval = Evaluator.EvaluateConcurrency(l.Manifest.Interleaving!.ResolveConditions, result);
    var prog = eval.Passed
        ? await progress.RecordSolveAsync(id, null, null)
        : await progress.GetAsync(id);

    return Results.Json(result with { Evaluation = eval, Progress = prog });
});

// ---- Reset ----
app.MapPost("/api/lessons/{id}/reset", async (string id, LessonCatalog cat, SqlExecutor exec) =>
{
    var l = cat.Get(id);
    if (l is null) return Results.NotFound();
    var ms = await exec.ResetAsync(l);
    return Results.Json(new ResetDto("reset", l.Database, ms));
});

// ---- Design modules ----
// Modules are lessons with kind="design", so seeding, isolation, running and
// reset are all the existing machinery. Only the canvas and its grading are new.

app.MapGet("/api/modules/{id}", async (string id, LessonCatalog cat, ProgressStore progress) =>
{
    var l = cat.Get(id);
    if (l is null || !l.IsDesign) return Results.NotFound();
    var m = l.Manifest;
    return Results.Json(new ModuleDetailDto(m.Id, m.Track, m.Kind, m.Level, m.Title, m.Description,
        m.Topics, m.EstimatedMinutes, m.Narrative, m.Hints, m.Steps, m.StartingModel,
        await progress.GetAsync(id), m.AzureUnsupported));
});

// The saved diagram. Falls back to the module's startingModel so a first visit
// opens on the intended canvas rather than an empty one.
app.MapGet("/api/modules/{id}/model", async (string id, LessonCatalog cat, ProgressStore progress) =>
{
    var l = cat.Get(id);
    if (l is null || !l.IsDesign) return Results.NotFound();
    var (jsonText, updated) = await progress.GetCanvasAsync(id);
    var model = jsonText is null
        ? l.Manifest.StartingModel
        : JsonSerializer.Deserialize<ErdModel>(jsonText, Json.Options);
    return Results.Json(new ModelDto(model, updated));
});

app.MapPut("/api/modules/{id}/model", async (string id, ModelSaveRequest req, LessonCatalog cat,
    ProgressStore progress) =>
{
    var l = cat.Get(id);
    if (l is null || !l.IsDesign) return Results.NotFound();
    await progress.SaveCanvasAsync(id, JsonSerializer.Serialize(req.Model ?? new ErdModel(), Json.Options));
    return Results.Json(new { saved = true });
});

app.MapPost("/api/modules/{id}/ddl", (string id, DdlRequest req, LessonCatalog cat) =>
{
    var l = cat.Get(id);
    if (l is null || !l.IsDesign) return Results.NotFound();
    try
    {
        var res = DdlGenerator.Generate(req.Model ?? new ErdModel());
        return Results.Json(res);
    }
    catch (DdlGenerator.InvalidModelException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

// Check: generate the DDL (or take the learner's own), run it in the module's
// isolated schema, read the resulting schema back, and grade THAT. The canvas is
// an input method for DDL, never the graded artefact — so hand-written DDL that
// produces the same schema passes identically.
app.MapPost("/api/modules/{id}/check", async (string id, CheckRequest req, LessonCatalog cat,
    SqlExecutor exec, SchemaReader schema, ProgressStore progress) =>
{
    var l = cat.Get(id);
    if (l is null || !l.IsDesign) return Results.NotFound();

    string ddl;
    var warnings = new List<string>();
    if (!string.IsNullOrWhiteSpace(req.Sql))
    {
        ddl = req.Sql!;
    }
    else
    {
        try
        {
            var gen = DdlGenerator.Generate(req.Model ?? new ErdModel());
            ddl = gen.Ddl;
            warnings = gen.Warnings;
        }
        catch (DdlGenerator.InvalidModelException ex)
        {
            return Results.Json(new CheckResult(false, ex.Message, "", warnings, null, null, null));
        }
    }

    // Reset the schema before applying the DDL, so Check is repeatable. Without
    // this, a second press fails with "There is already an object named ..." —
    // and iterating on a model is exactly what a learner does. Check means
    // "build my design from scratch and grade the result", so starting from the
    // seed state every time is also the semantically correct reading.
    await exec.ResetAsync(l);

    var art = await exec.RunAsync(l, ddl);
    if (!art.Success)
        return Results.Json(new CheckResult(false, art.Error, ddl, warnings, null, null, null));

    var schemaDto = await exec.SchemaExistsAsync(l.Database)
        ? await schema.ReadAsync(l.Database)
        : new SchemaDto(l.Database, false, new List<SchemaTableDto>());

    var eval = DesignEvaluator.Evaluate(l.Manifest.DesignConditions, schemaDto);
    var prog = eval.Passed
        ? await progress.RecordSolveAsync(id, null, null)
        : await progress.GetAsync(id);

    return Results.Json(new CheckResult(true, null, ddl, warnings, schemaDto, eval, prog));
});

app.MapPost("/api/modules/{id}/reset", async (string id, LessonCatalog cat, SqlExecutor exec,
    ProgressStore progress) =>
{
    var l = cat.Get(id);
    if (l is null || !l.IsDesign) return Results.NotFound();
    var ms = await exec.ResetAsync(l);
    // Reset means "start this module over", so the saved diagram goes back to
    // the module's starting point too.
    await progress.SaveCanvasAsync(id,
        JsonSerializer.Serialize(l.Manifest.StartingModel ?? new ErdModel(), Json.Options));
    return Results.Json(new ResetDto("reset", l.Database, ms));
});

app.MapGet("/api/modules/{id}/schema", async (string id, LessonCatalog cat,
    SqlExecutor exec, SchemaReader schema) =>
{
    var l = cat.Get(id);
    if (l is null || !l.IsDesign) return Results.NotFound();
    if (!await exec.SchemaExistsAsync(l.Database))
        return Results.Json(new SchemaDto(l.Database, false, new List<SchemaTableDto>()));
    return Results.Json(await schema.ReadAsync(l.Database));
});

// ---- Overall progress ----
// A null track means "every track" — that is what the Settings page wants. The
// SPA's track sidebars pass their own key so one track's count can't move
// because of progress in the other.
async Task<OverallProgressDto> BuildOverallProgressAsync(
    LessonCatalog cat, ProgressStore progress, TrackRegistry tracks, string? track)
{
    var prog = await progress.GetAllAsync();
    var scoped = track is null ? cat.All.ToList() : cat.ForTrack(tracks.Resolve(track).Key).ToList();
    var levelKeys = tracks.Resolve(track).Levels.Select(l => l.Key);

    var byLevel = levelKeys.Select(key =>
    {
        var lessons = scoped.Where(l => string.Equals(l.Manifest.Level, key, StringComparison.OrdinalIgnoreCase)).ToList();
        int solved = lessons.Count(l => prog.GetValueOrDefault(l.Manifest.Id)?.Solved == true);
        return new LevelProgressDto(key, lessons.Count, solved);
    }).ToList();

    int solvedTotal = scoped.Count(l => prog.GetValueOrDefault(l.Manifest.Id)?.Solved == true);
    return new OverallProgressDto(scoped.Count, solvedTotal, byLevel);
}

app.MapGet("/api/progress", async (string? track, LessonCatalog cat, ProgressStore progress,
        TrackRegistry tracks) =>
    Results.Json(await BuildOverallProgressAsync(cat, progress, tracks, track)));

// ---- Settings ----
app.MapGet("/api/settings/info", async (LessonCatalog cat, ProgressStore progress,
    TrackRegistry tracks, IConfiguration cfg) =>
{
    var cs = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(
        cfg.GetConnectionString("Sql") ?? "");
    var prog = await BuildOverallProgressAsync(cat, progress, tracks, null);
    return Results.Json(new SettingsInfoDto(cs.DataSource, cat.Count, prog));
});

// Re-runs every lesson's seed.sql, recreating each lesson database from scratch.
// This is the "set up the DB programmatically" action from the disaster-recovery
// scenario (SQL container/image deleted and recreated empty) -- no manual scripts needed.
async Task<ResetAllDatabasesResultDto> ResetAllDatabasesAsync(LessonCatalog cat, SqlExecutor exec)
{
    var sw = System.Diagnostics.Stopwatch.StartNew();
    var failures = new List<string>();
    int ok = 0;
    foreach (var l in cat.All)
    {
        try { await exec.ResetAsync(l); ok++; }
        catch (Exception ex) { failures.Add($"{l.Manifest.Id}: {ex.Message}"); }
    }
    sw.Stop();
    return new ResetAllDatabasesResultDto(ok, failures.Count, sw.ElapsedMilliseconds, failures);
}

app.MapPost("/api/settings/reset-all-databases", async (LessonCatalog cat, SqlExecutor exec) =>
    Results.Json(await ResetAllDatabasesAsync(cat, exec)));

// Clears all recorded lesson-completion progress (dbo.LessonProgress, in the
// shared app database — there is no separate AppMeta database).
app.MapPost("/api/settings/reset-progress", async (ProgressStore progress) =>
{
    var rows = await progress.ResetAllAsync();
    return Results.Json(new ResetProgressResultDto(rows));
});

// Lets the SPA know whether Docker-based actions are available in this deployment
// (only true locally, where the socket + project root are bind-mounted -- never on
// Azure Container Apps, which has no host Docker daemon to reach).
app.MapGet("/api/settings/capabilities", (DockerOps docker) =>
    Results.Json(new SettingsCapabilitiesDto(docker.IsAvailable())));

// Disaster recovery, run programmatically from the Settings page: deletes the
// sqlperf-sqlserver container/image (and its data volume, unless keepData), pulls a
// fresh SQL Server 2022 image, recreates the container via docker compose (against
// the HOST Docker daemon, reached through the socket mounted into this container),
// waits for it to report healthy, then reseeds every lesson database.
app.MapPost("/api/settings/recreate-sql-container", async (
    RecreateSqlContainerRequest? req, DockerOps docker, LessonCatalog cat, SqlExecutor exec) =>
{
    if (!docker.IsAvailable())
        return Results.Problem("Docker is not available in this deployment.", statusCode: 501);

    var sw = System.Diagnostics.Stopwatch.StartNew();
    using var cts = new CancellationTokenSource(TimeSpan.FromMinutes(6));
    var steps = await docker.RecreateSqlContainerAsync(req?.KeepData ?? false, cts.Token);
    var success = steps.Count > 0 && steps[^1] is { Step: "wait-for-healthy", Success: true };

    ResetAllDatabasesResultDto? reseed = null;
    if (success)
        reseed = await ResetAllDatabasesAsync(cat, exec);

    sw.Stop();
    return Results.Json(new RecreateSqlContainerResultDto(
        success && (reseed?.Failed ?? 0) == 0, sw.ElapsedMilliseconds, steps, reseed));
});

// ---- AI Tutor ----
app.MapGet("/api/tutor/status", (TutorService tutor) =>
    Results.Json(new { configured = tutor.IsConfigured }));

app.MapGet("/api/lessons/{id}/tutor/history", async (string id, TutorHistoryStore history) =>
    Results.Json(await history.LoadAsync(id)));

app.MapPost("/api/lessons/{id}/tutor/reset", async (string id, TutorHistoryStore history) =>
{
    await history.ClearAsync(id);
    return Results.Ok();
});

app.MapPost("/api/lessons/{id}/tutor/chat", async (
    string id, TutorChatRequest req, LessonCatalog cat, TutorService tutor,
    TutorHistoryStore historyStore, HttpContext http, CancellationToken ct) =>
{
    var l = cat.Get(id);
    if (l is null) { http.Response.StatusCode = 404; return; }
    if (string.IsNullOrWhiteSpace(req.Message)) { http.Response.StatusCode = 400; return; }

    var history = await historyStore.LoadAsync(id, ct);
    await historyStore.AppendAsync(id, new TutorMessage("user", req.Message, DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()), ct);

    http.Response.ContentType = "text/event-stream";
    http.Response.Headers["Cache-Control"] = "no-cache";
    http.Response.Headers["X-Accel-Buffering"] = "no";

    var sb = new System.Text.StringBuilder();
    try
    {
        await foreach (var chunk in tutor.StreamReplyAsync(l, history, req.Message, ct))
        {
            object evt = chunk.Delta is not null
                ? new { delta = chunk.Delta }
                : new { costZar = chunk.CostZar, promptTokens = chunk.PromptTokens, completionTokens = chunk.CompletionTokens };
            if (chunk.Delta is not null) sb.Append(chunk.Delta);
            await http.Response.WriteAsync($"data: {JsonSerializer.Serialize(evt, Json.Options)}\n\n", ct);
            await http.Response.Body.FlushAsync(ct);
        }
    }
    catch (Exception ex)
    {
        await http.Response.WriteAsync($"data: {JsonSerializer.Serialize(new { error = ex.Message }, Json.Options)}\n\n", ct);
    }
    finally
    {
        if (sb.Length > 0)
            await historyStore.AppendAsync(id, new TutorMessage("assistant", sb.ToString(), DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()), ct);
        await http.Response.WriteAsync("data: [DONE]\n\n", ct);
    }
});

app.Run();
