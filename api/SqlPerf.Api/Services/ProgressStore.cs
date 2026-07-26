using Microsoft.Data.SqlClient;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

// Progress lives in the `dbo` schema of the same shared app database that lesson
// content uses (see SqlExecutor) -- NOT a separate database, since a second database
// would be billable on Azure SQL's single-free-database tier and defeat the point of
// consolidating everything into one database.
public sealed class ProgressStore
{
    private readonly string _masterCs;
    private readonly string _appCs;
    private readonly string _appDatabase;
    private bool _ready;

    public ProgressStore(IConfiguration cfg)
    {
        var baseCs = cfg.GetConnectionString("Sql")
            ?? throw new InvalidOperationException("ConnectionStrings:Sql missing");
        _appDatabase = cfg["Sql:AppDatabase"] ?? "SqlPerfDb";
        _masterCs = new SqlConnectionStringBuilder(baseCs) { InitialCatalog = "master" }.ConnectionString;
        _appCs = new SqlConnectionStringBuilder(baseCs) { InitialCatalog = _appDatabase }.ConnectionString;
    }

    public async Task EnsureReadyAsync()
    {
        if (_ready) return;
        await using (var c = new SqlConnection(_masterCs))
        {
            await c.OpenAsync();
            // Azure SQL Database requires CREATE DATABASE to be the only statement in
            // its batch -- an "IF DB_ID(...) IS NULL CREATE DATABASE ..." conditional
            // (fine on-prem) fails there. Check existence separately first instead.
            // Also: DB_ID(name) on Azure SQL only resolves the CURRENTLY connected
            // database, returning NULL for any other database on the server even when
            // it exists -- query sys.databases directly instead.
            bool exists;
            await using (var cmd = new SqlCommand("SELECT 1 FROM sys.databases WHERE name = @db", c))
            {
                cmd.Parameters.AddWithValue("@db", _appDatabase);
                var r = await cmd.ExecuteScalarAsync();
                exists = r is not null && r != DBNull.Value;
            }
            if (!exists)
                await Exec(c, $"CREATE DATABASE [{_appDatabase}];");
            // One-time, database-wide, one-way-safe: lets any lesson (e.g.
            // a-19-snapshot-update-conflict) use SET TRANSACTION ISOLATION LEVEL
            // SNAPSHOT. Idempotent -- a no-op once already ON.
            await Exec(c, $"ALTER DATABASE [{_appDatabase}] SET ALLOW_SNAPSHOT_ISOLATION ON;");
        }
        await using (var c = new SqlConnection(_appCs))
        {
            await c.OpenAsync();
            await Exec(c, """
                IF OBJECT_ID('dbo.LessonProgress') IS NULL
                CREATE TABLE dbo.LessonProgress(
                    LessonId nvarchar(200) NOT NULL PRIMARY KEY,
                    Solved bit NOT NULL DEFAULT 0,
                    BestLogicalReads int NULL,
                    BestDurationMs int NULL,
                    SolvedAtUtc datetime2 NULL);
                """);
        }
        _ready = true;
    }

    private static async Task Exec(SqlConnection c, string sql)
    {
        await using var cmd = new SqlCommand(sql, c) { CommandTimeout = 60 };
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task<ProgressDto> GetAsync(string lessonId)
    {
        await EnsureReadyAsync();
        await using var c = new SqlConnection(_appCs);
        await c.OpenAsync();
        await using var cmd = new SqlCommand(
            "SELECT Solved, BestLogicalReads, BestDurationMs FROM dbo.LessonProgress WHERE LessonId=@id", c);
        cmd.Parameters.AddWithValue("@id", lessonId);
        await using var r = await cmd.ExecuteReaderAsync();
        if (await r.ReadAsync())
            return new ProgressDto(r.GetBoolean(0),
                r.IsDBNull(1) ? null : r.GetInt32(1),
                r.IsDBNull(2) ? null : r.GetInt32(2));
        return new ProgressDto(false, null, null);
    }

    public async Task<Dictionary<string, ProgressDto>> GetAllAsync()
    {
        await EnsureReadyAsync();
        var map = new Dictionary<string, ProgressDto>(StringComparer.OrdinalIgnoreCase);
        await using var c = new SqlConnection(_appCs);
        await c.OpenAsync();
        await using var cmd = new SqlCommand(
            "SELECT LessonId, Solved, BestLogicalReads, BestDurationMs FROM dbo.LessonProgress", c);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            map[r.GetString(0)] = new ProgressDto(r.GetBoolean(1),
                r.IsDBNull(2) ? null : r.GetInt32(2),
                r.IsDBNull(3) ? null : r.GetInt32(3));
        return map;
    }

    // Records a solve; keeps the best (lowest) reads/duration. Returns updated progress + newlySolved.
    public async Task<ProgressDto> RecordSolveAsync(string lessonId, int? logicalReads, int? durationMs)
    {
        await EnsureReadyAsync();
        var existing = await GetAsync(lessonId);
        var newlySolved = !existing.Solved;
        var bestReads = Min(existing.BestLogicalReads, logicalReads);
        var bestDur = Min(existing.BestDurationMs, durationMs);

        await using var c = new SqlConnection(_appCs);
        await c.OpenAsync();
        await using var cmd = new SqlCommand("""
            MERGE dbo.LessonProgress AS t
            USING (SELECT @id AS LessonId) AS s ON t.LessonId = s.LessonId
            WHEN MATCHED THEN UPDATE SET Solved=1, BestLogicalReads=@reads, BestDurationMs=@dur,
                SolvedAtUtc=COALESCE(t.SolvedAtUtc, SYSUTCDATETIME())
            WHEN NOT MATCHED THEN INSERT (LessonId,Solved,BestLogicalReads,BestDurationMs,SolvedAtUtc)
                VALUES (@id,1,@reads,@dur,SYSUTCDATETIME());
            """, c);
        cmd.Parameters.AddWithValue("@id", lessonId);
        cmd.Parameters.AddWithValue("@reads", (object?)bestReads ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@dur", (object?)bestDur ?? DBNull.Value);
        await cmd.ExecuteNonQueryAsync();

        return new ProgressDto(true, bestReads, bestDur, newlySolved);
    }

    private static int? Min(int? a, int? b) =>
        a is null ? b : b is null ? a : Math.Min(a.Value, b.Value);

    // Wipes all recorded progress. Used by the Settings "Reset my progress" action.
    public async Task<int> ResetAllAsync()
    {
        await EnsureReadyAsync();
        await using var c = new SqlConnection(_appCs);
        await c.OpenAsync();
        await using var cmd = new SqlCommand("DELETE FROM dbo.LessonProgress;", c) { CommandTimeout = 60 };
        return await cmd.ExecuteNonQueryAsync();
    }
}
