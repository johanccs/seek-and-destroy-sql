using System.Data;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

// Provisions lesson SCHEMAS (all lessons share one physical database, isolated by
// per-lesson SQL schema + a contained "EXECUTE AS" user, not by separate databases --
// this is what lets the whole app run on a single Azure SQL free-tier database).
// Runs learner SQL with stats + actual plan capture.
public sealed partial class SqlExecutor
{
    public const int RowCap = 500;
    public const int QueryTimeoutSec = 30;

    private readonly string _baseCs;
    private readonly string _appDatabase;
    private readonly HashSet<string> _seeded = new(StringComparer.OrdinalIgnoreCase);
    private readonly SemaphoreSlim _seedLock = new(1, 1);
    private readonly Dictionary<string, string> _baselines = new(StringComparer.OrdinalIgnoreCase);

    public SqlExecutor(IConfiguration cfg)
    {
        _baseCs = cfg.GetConnectionString("Sql")
            ?? throw new InvalidOperationException("ConnectionStrings:Sql missing");
        _appDatabase = cfg["Sql:AppDatabase"] ?? "SqlPerfDb";
    }

    private string AppCs =>
        new SqlConnectionStringBuilder(_baseCs) { InitialCatalog = _appDatabase }.ConnectionString;

    private static string UserOf(string schema) => "u_" + schema;

    public async Task<bool> SchemaExistsAsync(string schema)
    {
        await using var c = new SqlConnection(AppCs);
        await c.OpenAsync();
        await using var cmd = new SqlCommand("SELECT 1 FROM sys.schemas WHERE name = @s", c);
        cmd.Parameters.AddWithValue("@s", schema);
        var r = await cmd.ExecuteScalarAsync();
        return r is not null;
    }

    public async Task EnsureSeededAsync(Lesson lesson)
    {
        if (_seeded.Contains(lesson.Database)) return;
        await _seedLock.WaitAsync();
        try
        {
            if (_seeded.Contains(lesson.Database)) return;
            if (!await SchemaExistsAsync(lesson.Database))
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

    private async Task<string> ResultSignatureAsync(string schema, string sql)
    {
        await using var c = new SqlConnection(AppCs);
        await c.OpenAsync();
        await ImpersonateAsync(c, schema);
        try
        {
            await using var cmd = new SqlCommand(sql, c) { CommandTimeout = QueryTimeoutSec };
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
        finally
        {
            // Never return a connection to the pool while still impersonating.
            try { await ExecNonQuery(c, "BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH;"); } catch { }
        }
    }

    // Reverts any prior impersonation (harmless if none), then impersonates the
    // lesson's own contained user, so bare table names in lesson SQL resolve to that
    // lesson's schema via DEFAULT_SCHEMA -- no schema-qualification needed in content.
    // Always done at the START of every use (not just once) because a pooled
    // connection could otherwise carry over a previous lesson's impersonation.
    private static async Task ImpersonateAsync(SqlConnection c, string schema)
    {
        await ExecNonQuery(c, "BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH;");
        await ExecNonQuery(c, $"EXECUTE AS USER = '{UserOf(schema)}';");
    }

    private static async Task ExecNonQuery(SqlConnection c, string sql, int timeoutSec = 30)
    {
        await using var cmd = new SqlCommand(sql, c) { CommandTimeout = timeoutSec };
        await cmd.ExecuteNonQueryAsync();
    }

    // Drops every object owned by the lesson's schema (tables/views/procs/functions --
    // DROP SCHEMA fails while it still contains objects), then the contained user and
    // the schema itself. Safe to call when nothing exists yet (first run).
    private static async Task DropSchemaObjectsAsync(SqlConnection c, string schema, string user)
    {
        // Foreign keys go first, before any table drop is attempted. Dropping a
        // referenced parent table fails while a child still points at it, and
        // clearing every constraint up front is more robust than topologically
        // ordering the table drops: it also handles self-references and cycles,
        // which no ordering can. Design modules create FKs, so this is required.
        var fkDrops = new List<(string table, string name)>();
        await using (var cmd = new SqlCommand("""
            SELECT t.name, fk.name
            FROM sys.foreign_keys fk
            JOIN sys.tables t ON t.object_id = fk.parent_object_id
            WHERE t.schema_id = SCHEMA_ID(@schema)
            """, c))
        {
            cmd.Parameters.AddWithValue("@schema", schema);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                fkDrops.Add((r.GetString(0), r.GetString(1)));
        }
        foreach (var (table, name) in fkDrops)
            await TryExecAsync(c, $"ALTER TABLE [{schema}].[{table}] DROP CONSTRAINT [{name}];");

        var drops = new List<(string kind, string name)>();
        await using (var cmd = new SqlCommand("""
            SELECT o.type, o.name
            FROM sys.objects o
            JOIN sys.schemas s ON s.schema_id = o.schema_id
            WHERE s.name = @schema AND o.type IN ('U','V','P','FN','IF','TF','TR')
            ORDER BY CASE LTRIM(RTRIM(o.type))
                         WHEN 'TR' THEN 0   -- triggers before their tables
                         WHEN 'P'  THEN 1
                         WHEN 'V'  THEN 2   -- a SCHEMABINDING view blocks its base table
                         WHEN 'FN' THEN 3
                         WHEN 'IF' THEN 3
                         WHEN 'TF' THEN 3
                         ELSE 9             -- tables last
                     END
            """, c))
        {
            cmd.Parameters.AddWithValue("@schema", schema);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                drops.Add((r.GetString(0).Trim(), r.GetString(1)));
        }

        // One object refusing to drop must not strand the whole schema, so
        // failures are collected and retried once after everything else is gone
        // (which is usually enough — the blocker is normally a dependency).
        var failed = new List<(string kind, string name)>();
        foreach (var d in drops)
            if (!await TryDropAsync(c, schema, d.kind, d.name))
                failed.Add(d);
        foreach (var d in failed)
            await TryDropAsync(c, schema, d.kind, d.name);

        await using (var cmd = new SqlCommand(
            "IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @u) DROP USER [" + user + "];", c))
        {
            cmd.Parameters.AddWithValue("@u", user);
            await cmd.ExecuteNonQueryAsync();
        }
        await using (var cmd = new SqlCommand(
            "IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = @s) EXEC('DROP SCHEMA [" + schema + "]');", c))
        {
            cmd.Parameters.AddWithValue("@s", schema);
            await cmd.ExecuteNonQueryAsync();
        }
    }

    private static async Task<bool> TryDropAsync(SqlConnection c, string schema, string kind, string name)
    {
        var keyword = kind switch
        {
            "U" => "TABLE",
            "V" => "VIEW",
            "P" => "PROCEDURE",
            "TR" => "TRIGGER",
            "FN" or "IF" or "TF" => "FUNCTION",
            _ => null
        };
        if (keyword is null) return true;
        return await TryExecAsync(c, $"DROP {keyword} [{schema}].[{name}];");
    }

    private static async Task<bool> TryExecAsync(SqlConnection c, string sql)
    {
        try { await ExecNonQuery(c, sql, 60); return true; }
        catch (SqlException) { return false; }
    }

    private async Task RunSeedAsync(Lesson lesson)
    {
        if (string.IsNullOrWhiteSpace(lesson.SeedSql))
            throw new InvalidOperationException($"Lesson {lesson.Manifest.Id} has no seed.sql");

        var schema = lesson.Database;
        var user = UserOf(schema);

        await using var c = new SqlConnection(AppCs);
        await c.OpenAsync();

        await DropSchemaObjectsAsync(c, schema, user);
        // CREATE SCHEMA must be the only statement in its batch -- EXEC(...) sidesteps that.
        await ExecNonQuery(c, $"EXEC('CREATE SCHEMA [{schema}]');");
        await ExecNonQuery(c, $"CREATE USER [{user}] WITHOUT LOGIN WITH DEFAULT_SCHEMA = [{schema}];");
        // db_owner is broad, but this is a trusted single-tenant learning app where every
        // lesson's DDL (partitioning, columnstore, functions, indexes) needs full rights
        // within its own schema; narrower per-lesson roles aren't worth the added friction.
        await ExecNonQuery(c, $"ALTER ROLE db_owner ADD MEMBER [{user}];");

        await ImpersonateAsync(c, schema);
        try
        {
            foreach (var batch in SplitBatches(lesson.SeedSql))
            {
                if (string.IsNullOrWhiteSpace(batch)) continue;
                await using var cmd = new SqlCommand(batch, c) { CommandTimeout = 120 };
                await cmd.ExecuteNonQueryAsync();
            }
        }
        finally
        {
            await ExecNonQuery(c, "BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH;");
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

        await using var c = new SqlConnection(AppCs);
        c.InfoMessage += (_, e) =>
        {
            foreach (SqlError err in e.Errors) messages.Add(err.Message);
        };
        await c.OpenAsync();
        await ImpersonateAsync(c, lesson.Database);

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
        finally
        {
            // Never return a connection to the pool while still impersonating.
            try { await ExecNonQuery(c, "BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH;"); } catch { }
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
