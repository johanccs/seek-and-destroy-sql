using System.Data;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

// Provisions lesson databases and runs learner SQL with stats + actual plan capture.
public sealed partial class SqlExecutor
{
    public const int RowCap = 500;
    public const int QueryTimeoutSec = 30;

    private readonly string _baseCs;
    private readonly HashSet<string> _seeded = new(StringComparer.OrdinalIgnoreCase);
    private readonly SemaphoreSlim _seedLock = new(1, 1);
    private readonly Dictionary<string, string> _baselines = new(StringComparer.OrdinalIgnoreCase);

    public SqlExecutor(IConfiguration cfg) =>
        _baseCs = cfg.GetConnectionString("Sql")
            ?? throw new InvalidOperationException("ConnectionStrings:Sql missing");

    private string CsFor(string db) =>
        new SqlConnectionStringBuilder(_baseCs) { InitialCatalog = db }.ConnectionString;
    private string MasterCs =>
        new SqlConnectionStringBuilder(_baseCs) { InitialCatalog = "master" }.ConnectionString;

    public async Task<bool> DbExistsAsync(string db)
    {
        await using var c = new SqlConnection(MasterCs);
        await c.OpenAsync();
        await using var cmd = new SqlCommand("SELECT DB_ID(@db)", c);
        cmd.Parameters.AddWithValue("@db", db);
        var r = await cmd.ExecuteScalarAsync();
        return r is not null && r != DBNull.Value;
    }

    public async Task EnsureSeededAsync(Lesson lesson)
    {
        if (_seeded.Contains(lesson.Database)) return;
        await _seedLock.WaitAsync();
        try
        {
            if (_seeded.Contains(lesson.Database)) return;
            if (!await DbExistsAsync(lesson.Database))
                await RunSeedAsync(lesson);
            _seeded.Add(lesson.Database);
        }
        finally { _seedLock.Release(); }
    }

    public async Task<long> ResetAsync(Lesson lesson)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        await RunSeedAsync(lesson);
        _seeded.Add(lesson.Database);
        _baselines.Remove(lesson.Manifest.Id);
        sw.Stop();
        return sw.ElapsedMilliseconds;
    }

    // Canonical (order-insensitive) signature of the lesson's starting query result,
    // used by the `resultUnchanged` rule. Captured once per seed/reset.
    public async Task<string> GetBaselineAsync(Lesson lesson)
    {
        await EnsureSeededAsync(lesson);
        if (_baselines.TryGetValue(lesson.Manifest.Id, out var cached)) return cached;
        var sig = await ResultSignatureAsync(lesson.Database, lesson.Manifest.StartingQuery);
        _baselines[lesson.Manifest.Id] = sig;
        return sig;
    }

    public static string SignatureOf(ResultSetDto? rs)
    {
        if (rs is null) return "";
        var rows = rs.Rows.Select(r => string.Join("", r.Select(v => v?.ToString() ?? "␀")));
        return string.Join("", rows.OrderBy(s => s, StringComparer.Ordinal));
    }

    private async Task<string> ResultSignatureAsync(string db, string sql)
    {
        await using var c = new SqlConnection(CsFor(db));
        await c.OpenAsync();
        await using var cmd = new SqlCommand(sql, c) { CommandTimeout = QueryTimeoutSec };
        try
        {
            await using var reader = await cmd.ExecuteReaderAsync();
            var cols = Enumerable.Range(0, reader.FieldCount).Select(reader.GetName).ToList();
            var rows = new List<List<object?>>();
            while (await reader.ReadAsync())
            {
                var row = new List<object?>(cols.Count);
                for (int i = 0; i < reader.FieldCount; i++)
                    row.Add(reader.IsDBNull(i) ? null : Normalize(reader.GetValue(i)));
                rows.Add(row);
            }
            return SignatureOf(new ResultSetDto(cols, rows, rows.Count, false));
        }
        catch { return ""; }
    }

    private async Task RunSeedAsync(Lesson lesson)
    {
        if (string.IsNullOrWhiteSpace(lesson.SeedSql))
            throw new InvalidOperationException($"Lesson {lesson.Manifest.Id} has no seed.sql");

        // seed.sql drops+recreates its own DB, so run batches against master.
        await using var c = new SqlConnection(MasterCs);
        await c.OpenAsync();
        foreach (var batch in SplitBatches(lesson.SeedSql))
        {
            if (string.IsNullOrWhiteSpace(batch)) continue;
            await using var cmd = new SqlCommand(batch, c) { CommandTimeout = 120 };
            await cmd.ExecuteNonQueryAsync();
        }
    }

    public static IEnumerable<string> SplitBatches(string sql)
    {
        var sb = new StringBuilder();
        foreach (var line in sql.Replace("\r\n", "\n").Split('\n'))
        {
            if (GoLine().IsMatch(line))
            {
                yield return sb.ToString();
                sb.Clear();
            }
            else sb.Append(line).Append('\n');
        }
        if (sb.Length > 0) yield return sb.ToString();
    }

    // Runs learner SQL and returns raw execution artifacts (evaluation is layered on top).
    public async Task<ExecArtifacts> RunAsync(Lesson lesson, string userSql)
    {
        await EnsureSeededAsync(lesson);

        var messages = new List<string>();
        var resultSets = new List<ResultSetDto>();
        string? planXml = null;
        int rowsAffected = 0;

        await using var c = new SqlConnection(CsFor(lesson.Database));
        c.InfoMessage += (_, e) =>
        {
            foreach (SqlError err in e.Errors) messages.Add(err.Message);
        };
        await c.OpenAsync();

        var wrapped = "SET STATISTICS IO ON; SET STATISTICS TIME ON; SET STATISTICS XML ON;\n" + userSql;
        await using var cmd = new SqlCommand(wrapped, c) { CommandTimeout = QueryTimeoutSec };

        try
        {
            await using var reader = await cmd.ExecuteReaderAsync();
            do
            {
                if (reader.FieldCount == 1 && IsShowPlanColumn(reader.GetName(0)))
                {
                    if (await reader.ReadAsync() && !reader.IsDBNull(0))
                        planXml = reader.GetString(0);
                    continue;
                }
                if (reader.FieldCount == 0) continue;

                var cols = Enumerable.Range(0, reader.FieldCount).Select(reader.GetName).ToList();
                var rows = new List<List<object?>>();
                int count = 0;
                bool truncated = false;
                while (await reader.ReadAsync())
                {
                    count++;
                    var row = new List<object?>(cols.Count);
                    for (int i = 0; i < reader.FieldCount; i++)
                        row.Add(reader.IsDBNull(i) ? null : Normalize(reader.GetValue(i)));
                    if (rows.Count < RowCap) rows.Add(row); else truncated = true;
                }
                resultSets.Add(new ResultSetDto(cols, rows, count, truncated));
            }
            while (await reader.NextResultAsync());

            rowsAffected = reader.RecordsAffected < 0 ? 0 : reader.RecordsAffected;
        }
        catch (SqlException ex)
        {
            return new ExecArtifacts(false, ex.Message, resultSets, null, null, messages, 0);
        }

        var stats = ParseStats(messages, rowsAffected);
        return new ExecArtifacts(true, null, resultSets, stats, planXml, messages, rowsAffected);
    }

    private static bool IsShowPlanColumn(string name) =>
        name.Contains("Showplan", StringComparison.OrdinalIgnoreCase) ||
        name.Contains("XML Showplan", StringComparison.OrdinalIgnoreCase);

    private static object? Normalize(object v) => v switch
    {
        byte[] b => Convert.ToHexString(b),
        DateTime d => d.ToString("o"),
        decimal m => m,
        _ => v
    };

    private static StatsDto ParseStats(List<string> messages, int rowsAffected)
    {
        var perTable = new Dictionary<string, PerTableStat>(StringComparer.OrdinalIgnoreCase);
        int totalLogical = 0, totalPhysical = 0, cpu = 0, elapsed = 0;

        foreach (var m in messages)
        {
            foreach (Match io in IoRegex().Matches(m))
            {
                var t = io.Groups["t"].Value;
                int sc = int.Parse(io.Groups["sc"].Value);
                int lr = int.Parse(io.Groups["lr"].Value);
                int pr = int.Parse(io.Groups["pr"].Value);
                totalLogical += lr;
                totalPhysical += pr;
                perTable[t] = new PerTableStat(t, lr, pr, sc);
            }
            if (m.Contains("Execution Times", StringComparison.OrdinalIgnoreCase))
            {
                var tm = TimeRegex().Match(m);
                if (tm.Success)
                {
                    cpu += int.Parse(tm.Groups["cpu"].Value);
                    elapsed += int.Parse(tm.Groups["el"].Value);
                }
            }
        }

        return new StatsDto(totalLogical, totalPhysical, cpu, elapsed, rowsAffected, perTable.Values.ToList());
    }

    [GeneratedRegex(@"^\s*GO\s*$", RegexOptions.IgnoreCase)]
    private static partial Regex GoLine();

    [GeneratedRegex(@"Table '(?<t>[^']+)'\. Scan count (?<sc>\d+), logical reads (?<lr>\d+), physical reads (?<pr>\d+)")]
    private static partial Regex IoRegex();

    [GeneratedRegex(@"CPU time = (?<cpu>\d+) ms,\s*elapsed time = (?<el>\d+) ms")]
    private static partial Regex TimeRegex();
}

public sealed record ExecArtifacts(
    bool Success, string? Error, List<ResultSetDto> ResultSets, StatsDto? Stats,
    string? PlanXml, List<string> Messages, int RowsAffected);
