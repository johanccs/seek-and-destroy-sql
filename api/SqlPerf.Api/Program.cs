using SqlPerf.Api.Models;
using SqlPerf.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<LessonCatalog>();
builder.Services.AddSingleton<SqlExecutor>();
builder.Services.AddSingleton<ConcurrencyRunner>();
builder.Services.AddSingleton<ProgressStore>();
builder.Services.AddSingleton<DockerOps>();
builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    o.SerializerOptions.DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.Never;
});

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
app.UseCors();

// Warm up AppMeta in the background so the first request isn't slow (non-fatal if DB down).
_ = Task.Run(async () =>
{
    try { await app.Services.GetRequiredService<ProgressStore>().EnsureReadyAsync(); }
    catch (Exception ex) { app.Logger.LogWarning(ex, "AppMeta warmup failed (SQL not ready yet?)"); }
});

// ---- Health ----
app.MapGet("/api/health", async (LessonCatalog cat, ProgressStore progress) =>
{
    string sql = "disconnected";
    try { await progress.EnsureReadyAsync(); sql = "connected"; } catch { }
    return Results.Json(new HealthDto("ok", sql, cat.Count));
});

// ---- Curriculum ----
var levelTitles = new (string key, string title, string description)[]
{
    ("beginner", "Beginner",
        "The fundamentals of making SQL Server fast: how indexes turn scans into seeks, why wrapping a column in a function or the wrong data type quietly disables an index, and how to cover, order, and range-search your data. Master these and you'll fix the majority of everyday slow queries."),
    ("intermediate", "Intermediate",
        "Sharper indexing and query-shape skills: covering and composite indexes, filtered indexes, key ordering, keyset pagination, sargable rewrites, implicit-conversion traps on joins, and turning accidental Cartesian products and EXISTS/aggregate patterns into efficient plans."),
    ("advanced", "Advanced",
        "Where the optimizer and the engine get subtle: parameter sniffing, stale statistics, tipping points, heaps and RID lookups, anti-joins, catch-all queries, and a full arc of concurrency — blocking, deadlocks, lock escalation, isolation levels, and snapshot conflicts — validated against a real two-session engine."),
    ("expert", "Expert",
        "Deep engine internals and analytics: scalar-UDF and window-function costs, columnstore and batch mode, partitioning, compression, tempdb spills and memory grants, worktable spools, RANGE-vs-ROWS frames, top-N-per-group, and reading the plan's own warnings and missing-index hints."),
};

app.MapGet("/api/levels", async (LessonCatalog cat, ProgressStore progress) =>
{
    var prog = await progress.GetAllAsync();
    var levels = levelTitles.Select(lt =>
    {
        var lessons = cat.All
            .Where(l => string.Equals(l.Manifest.Level, lt.key, StringComparison.OrdinalIgnoreCase))
            .OrderBy(l => l.Manifest.Order)
            .Select(l =>
            {
                var p = prog.GetValueOrDefault(l.Manifest.Id) ?? new ProgressDto(false, null, null);
                return new LessonSummaryDto(l.Manifest.Id, l.Manifest.Order, l.Manifest.Title,
                    l.Manifest.Topics, l.Manifest.EstimatedMinutes, l.IsConcurrency,
                    p.Solved, p.BestLogicalReads, p.BestDurationMs, l.Manifest.Description);
            }).ToList();
        return new LevelDto(lt.key, lt.title, lt.description, lessons);
    }).ToList();
    return Results.Json(levels);
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
        l.Manifest.Hints, l.IsConcurrency, interleaving, p, l.Manifest.Description));
});

app.MapGet("/api/lessons/{id}/solution", (string id, LessonCatalog cat) =>
{
    var l = cat.Get(id);
    return l is null ? Results.NotFound() : Results.Json(new SolutionDto(l.SolutionSql));
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

// ---- Overall progress ----
async Task<OverallProgressDto> BuildOverallProgressAsync(LessonCatalog cat, ProgressStore progress)
{
    var prog = await progress.GetAllAsync();
    var byLevel = levelTitles.Select(lt =>
    {
        var lessons = cat.All.Where(l => string.Equals(l.Manifest.Level, lt.key, StringComparison.OrdinalIgnoreCase)).ToList();
        int solved = lessons.Count(l => prog.GetValueOrDefault(l.Manifest.Id)?.Solved == true);
        return new LevelProgressDto(lt.key, lessons.Count, solved);
    }).ToList();
    int total = cat.Count;
    int solvedTotal = cat.All.Count(l => prog.GetValueOrDefault(l.Manifest.Id)?.Solved == true);
    return new OverallProgressDto(total, solvedTotal, byLevel);
}

app.MapGet("/api/progress", async (LessonCatalog cat, ProgressStore progress) =>
    Results.Json(await BuildOverallProgressAsync(cat, progress)));

// ---- Settings ----
app.MapGet("/api/settings/info", async (LessonCatalog cat, ProgressStore progress, IConfiguration cfg) =>
{
    var cs = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(
        cfg.GetConnectionString("Sql") ?? "");
    var prog = await BuildOverallProgressAsync(cat, progress);
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

// Clears all recorded lesson-completion progress (AppMeta.dbo.LessonProgress).
app.MapPost("/api/settings/reset-progress", async (ProgressStore progress) =>
{
    var rows = await progress.ResetAllAsync();
    return Results.Json(new ResetProgressResultDto(rows));
});

// Disaster recovery, run programmatically from the Settings page: deletes the
// sqlperf-sqlserver container/image (and its data volume, unless keepData), pulls a
// fresh SQL Server 2022 image, recreates the container via docker compose (against
// the HOST Docker daemon, reached through the socket mounted into this container),
// waits for it to report healthy, then reseeds every lesson database.
app.MapPost("/api/settings/recreate-sql-container", async (
    RecreateSqlContainerRequest? req, DockerOps docker, LessonCatalog cat, SqlExecutor exec) =>
{
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

app.Run();
