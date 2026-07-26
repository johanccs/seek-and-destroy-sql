using System.Text.Json;
using System.Text.Json.Serialization;

namespace SqlPerf.Api.Models;

// ---------- Lesson manifest (mirrors docs/CONTRACT.md section 2) ----------

public sealed class Manifest
{
    public string Id { get; set; } = "";
    public string Level { get; set; } = "";
    public int Order { get; set; }
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public List<string> Topics { get; set; } = new();
    public int EstimatedMinutes { get; set; }
    public string Narrative { get; set; } = "";
    public string StartingQuery { get; set; } = "";
    public string? Database { get; set; }
    public List<string> Hints { get; set; } = new();
    public List<RuleSpec> PassConditions { get; set; } = new();
    public Interleaving? Interleaving { get; set; }
    // True for lessons that can't fully run on Azure SQL Database's free tier
    // (e.g. columnstore indexes require Standard S3+/Premium). Surfaced so the SPA
    // can show a clear note instead of a confusing runtime failure.
    public bool AzureUnsupported { get; set; }
}

public sealed class RuleSpec
{
    public string Type { get; set; } = "";
    public string? Operator { get; set; }
    public string? Index { get; set; }
    public string? Table { get; set; }
    public string? Warning { get; set; }
    public double? Value { get; set; }
}

public sealed class Interleaving
{
    public string? Description { get; set; }
    public Dictionary<string, List<InterleaveStep>> Sessions { get; set; } = new();
    public List<RuleSpec> ResolveConditions { get; set; } = new();
    public string? SolutionNote { get; set; }
}

public sealed class InterleaveStep
{
    public string Sql { get; set; } = "";
    public int AfterMs { get; set; }
}

// In-memory lesson record (manifest + sibling scripts + resolved db name).
public sealed class Lesson
{
    public required Manifest Manifest { get; init; }
    public required string SeedSql { get; init; }
    public required string SolutionSql { get; init; }
    public required string Database { get; init; }
    public bool IsConcurrency => Manifest.Interleaving is not null;
}

// ---------- API response DTOs (CONTRACT section 3) ----------

public sealed record HealthDto(string Status, string SqlServer, int LessonsLoaded);

public sealed record LevelDto(string Level, string Title, string Description, List<LessonSummaryDto> Lessons);

public sealed record LessonSummaryDto(
    string Id, int Order, string Title, List<string> Topics, int EstimatedMinutes,
    bool IsConcurrency, bool Solved, int? BestLogicalReads, int? BestDurationMs, string Description,
    bool AzureUnsupported);

public sealed record LessonDetailDto(
    string Id, string Level, string Title, List<string> Topics, int EstimatedMinutes,
    string Narrative, string StartingQuery, List<string> Hints, bool IsConcurrency,
    object? Interleaving, ProgressDto Progress, string Description, bool AzureUnsupported);

public sealed record ProgressDto(bool Solved, int? BestLogicalReads, int? BestDurationMs, bool NewlySolved = false);

public sealed record SolutionDto(string Solution);

public sealed record ResetDto(string Status, string Database, long ElapsedMs);

// ---------- Settings ----------

public sealed record SettingsInfoDto(
    string SqlServerHost, int LessonsLoaded, OverallProgressDto Progress);

public sealed record ResetAllDatabasesResultDto(
    int LessonsReset, int Failed, long ElapsedMs, List<string> Failures);

public sealed record ResetProgressResultDto(int RowsCleared);

public sealed record RecreateSqlContainerRequest(bool KeepData);

public sealed record SettingsCapabilitiesDto(bool RecreateSqlContainer);

public sealed record RecreateSqlContainerResultDto(
    bool Success, long ElapsedMs, List<Services.DockerStepResult> Steps,
    ResetAllDatabasesResultDto? Reseed);

public sealed record RunRequest(string Sql);

public sealed record ResultSetDto(List<string> Columns, List<List<object?>> Rows, int RowCount, bool Truncated);

public sealed record PerTableStat(string Table, int LogicalReads, int PhysicalReads, int ScanCount);

public sealed record StatsDto(
    int TotalLogicalReads, int TotalPhysicalReads, int CpuTimeMs, int ElapsedTimeMs,
    int RowsAffected, List<PerTableStat> PerTable);

public sealed class PlanNode
{
    public int NodeId { get; set; }
    public string PhysicalOp { get; set; } = "";
    public string LogicalOp { get; set; } = "";
    public double EstimateRows { get; set; }
    public double? ActualRows { get; set; }
    public double EstimatedCostPercent { get; set; }
    public string? Object { get; set; }
    public List<string> Warnings { get; set; } = new();
    public List<PlanNode> Children { get; set; } = new();
}

public sealed record PlanWarning(string Type, double Impact, string Detail);
public sealed record MissingIndexDto(double Impact, string Statement);

public sealed record PlanDto(PlanNode? Root, List<PlanWarning> Warnings, List<MissingIndexDto> MissingIndexes);

public sealed record ConditionResultDto(string Type, string Label, bool Passed, string Detail);
public sealed record EvaluationDto(bool Passed, List<ConditionResultDto> Conditions);

public sealed record RunResult(
    bool Success, string? Error, List<ResultSetDto> ResultSets, StatsDto? Stats,
    PlanDto? Plan, List<string> Messages, EvaluationDto? Evaluation, ProgressDto? Progress);

public sealed record ConcurrencyRunRequest(Dictionary<string, List<InterleaveStep>> Sessions);

public sealed record TimelineEvent(int TMs, string Session, string Event, string Detail);

public sealed record ConcurrencyResult(
    string Outcome, string? DeadlockVictim, List<TimelineEvent> Timeline,
    string? DeadlockGraphXml, EvaluationDto Evaluation, ProgressDto Progress);

public sealed record OverallProgressDto(int TotalLessons, int SolvedLessons, List<LevelProgressDto> ByLevel);
public sealed record LevelProgressDto(string Level, int Total, int Solved);

public static class Json
{
    public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
    };
}
