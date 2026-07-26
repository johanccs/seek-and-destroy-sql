using System.Collections.Concurrent;
using System.Diagnostics;
using Microsoft.Data.SqlClient;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

// Runs a scripted two-session interleaving server-side to reproduce blocking / deadlocks,
// then reports a timeline for the UI sequence diagram.
public sealed class ConcurrencyRunner
{
    public const int CapMs = 15_000;
    private readonly string _baseCs;

    public ConcurrencyRunner(IConfiguration cfg) =>
        _baseCs = cfg.GetConnectionString("Sql")
            ?? throw new InvalidOperationException("ConnectionStrings:Sql missing");

    private string CsFor(string db) =>
        new SqlConnectionStringBuilder(_baseCs) { InitialCatalog = db }.ConnectionString;

    public async Task<ConcurrencyResult> RunAsync(string db, Dictionary<string, List<InterleaveStep>> sessions)
    {
        var events = new ConcurrentBag<TimelineEvent>();
        var sw = Stopwatch.StartNew();
        var spids = new ConcurrentDictionary<string, int>();
        string? deadlockVictim = null;
        string outcome = "completed";
        var errors = new ConcurrentBag<string>();

        using var cts = new CancellationTokenSource(CapMs + 2000);

        async Task RunSession(string name, List<InterleaveStep> steps)
        {
            try
            {
                await using var c = new SqlConnection(CsFor(db));
                await c.OpenAsync(cts.Token);
                await using (var spidCmd = new SqlCommand("SELECT @@SPID", c))
                    spids[name] = Convert.ToInt32(await spidCmd.ExecuteScalarAsync(cts.Token));

                for (int i = 0; i < steps.Count; i++)
                {
                    var step = steps[i];
                    var wait = step.AfterMs - (int)sw.ElapsedMilliseconds;
                    if (wait > 0) await Task.Delay(wait, cts.Token);

                    if (i == 0) Add(events, sw, name, "begin", First(step.Sql));
                    try
                    {
                        await using var cmd = new SqlCommand(step.Sql, c) { CommandTimeout = CapMs / 1000 };
                        await cmd.ExecuteNonQueryAsync(cts.Token);
                        var ev = step.Sql.Contains("COMMIT", StringComparison.OrdinalIgnoreCase) ? "commit" : "acquired";
                        Add(events, sw, name, ev, First(step.Sql));
                    }
                    catch (SqlException ex) when (ex.Number == 1205)
                    {
                        deadlockVictim = name;
                        outcome = "deadlock";
                        Add(events, sw, name, "deadlock-victim", "chosen as deadlock victim (1205)");
                        return;
                    }
                    catch (SqlException ex) when (ex.Number == -2)
                    {
                        if (outcome == "completed") outcome = "blocked-timeout";
                        Add(events, sw, name, "timeout", "command timed out while blocked");
                        return;
                    }
                }
            }
            catch (OperationCanceledException)
            {
                if (outcome == "completed") outcome = "blocked-timeout";
            }
            catch (SqlException ex)
            {
                errors.Add($"{name}: {ex.Message}");
                if (outcome == "completed") outcome = "error";
            }
        }

        // Poll for blocking among our two SPIDs.
        var poller = Task.Run(async () =>
        {
            var blockedActive = new HashSet<string>();
            try
            {
                await using var c = new SqlConnection(CsFor(db));
                await c.OpenAsync(cts.Token);
                while (!cts.IsCancellationRequested)
                {
                    if (spids.Count == 2)
                    {
                        await using var cmd = new SqlCommand(
                            "SELECT session_id, blocking_session_id, wait_type FROM sys.dm_exec_requests " +
                            "WHERE session_id IN (@a,@b) AND blocking_session_id <> 0", c);
                        cmd.Parameters.AddWithValue("@a", spids.GetValueOrDefault("A", -1));
                        cmd.Parameters.AddWithValue("@b", spids.GetValueOrDefault("B", -1));
                        var nowBlocked = new HashSet<string>();
                        await using var r = await cmd.ExecuteReaderAsync(cts.Token);
                        while (await r.ReadAsync(cts.Token))
                        {
                            // session_id / blocking_session_id are smallint (Int16) in the DMV.
                            int sid = Convert.ToInt32(r.GetValue(0));
                            int blocker = Convert.ToInt32(r.GetValue(1));
                            var name = spids.FirstOrDefault(kv => kv.Value == sid).Key;
                            if (name is null) continue;
                            nowBlocked.Add(name);
                            if (blockedActive.Add(name))
                                Add(events, sw, name, "blocked",
                                    $"waiting ({(r.IsDBNull(2) ? "LOCK" : r.GetString(2))}) on session {blocker}");
                        }
                        blockedActive.IntersectWith(nowBlocked);
                    }
                    await Task.Delay(40, cts.Token);
                }
            }
            catch (OperationCanceledException) { }
            catch { /* poller best-effort */ }
        }, cts.Token);

        var runners = sessions.Select(s => RunSession(s.Key, s.Value)).ToArray();
        var done = Task.WhenAll(runners);
        await Task.WhenAny(done, Task.Delay(CapMs, cts.Token));
        cts.Cancel();
        try { await done; } catch { }
        try { await poller; } catch { }

        string? deadlockGraph = outcome == "deadlock" ? await TryGetDeadlockGraph(db) : null;

        var timeline = events.OrderBy(e => e.TMs).ToList();
        return new ConcurrencyResult(outcome, deadlockVictim, timeline, deadlockGraph,
            new EvaluationDto(true, new()), new ProgressDto(false, null, null));
    }

    private static void Add(ConcurrentBag<TimelineEvent> bag, Stopwatch sw, string session, string ev, string detail) =>
        bag.Add(new TimelineEvent((int)sw.ElapsedMilliseconds, session, ev, detail));

    private static string First(string sql) =>
        sql.Trim().Split('\n')[0].Trim() is { Length: > 80 } s ? s[..80] + "…" : sql.Trim().Split('\n')[0].Trim();

    // Best-effort: read the most recent deadlock graph from the system_health XEvent session.
    private async Task<string?> TryGetDeadlockGraph(string db)
    {
        try
        {
            await using var c = new SqlConnection(CsFor(db));
            await c.OpenAsync();
            await using var cmd = new SqlCommand("""
                SELECT TOP 1 CAST(event_data AS xml).value('(event/data[@name="xml_report"]/value)[1]','nvarchar(max)')
                FROM (SELECT CAST(target_data AS xml) td FROM sys.dm_xe_session_targets t
                      JOIN sys.dm_xe_sessions s ON s.address = t.event_session_address
                      WHERE s.name = 'system_health' AND t.target_name = 'ring_buffer') rb
                CROSS APPLY td.nodes('//RingBufferTarget/event[@name="xml_deadlock_report"]') AS q(event_data)
                ORDER BY 1 DESC;
                """, c) { CommandTimeout = 5 };
            var r = await cmd.ExecuteScalarAsync();
            return r as string;
        }
        catch { return null; }
    }
}
