using System.Text.Json;
using System.Text.Json.Serialization;

namespace SqlPerf.Api.Models;

// ---------- Lesson manifest (mirrors docs/CONTRACT.md section 2) ----------

public sealed class Manifest
{
    public string Id { get; set; } = "";
    // Which curriculum this belongs to. Defaults to the performance track so the
    // 80 manifests written before tracks existed keep loading unchanged.
    public string Track { get; set; } = "perf";
    // What kind of exercise this is, which decides the widget the SPA renders:
    // "query" (Monaco + plan/stats), "design" (ERD canvas + generated DDL).
    // Concurrency lessons are still detected from the Interleaving block.
    public string Kind { get; set; } = "query";
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
    // Design modules: graded against the schema the learner's DDL actually
    // created. A module may carry both these and PassConditions, in which case
    // the results concatenate into one evaluation.
    public List<RuleSpec> DesignConditions { get; set; } = new();
    public List<ModuleStep> Steps { get; set; } = new();
    // Where the module's technical claims were verified. Kept in the manifest so
    // the content stays auditable rather than resting on the author's memory.
    public List<ManifestReference> References { get; set; } = new();
    public ErdModel? StartingModel { get; set; }
    public ErdModel? TargetModel { get; set; }
    public Interleaving? Interleaving { get; set; }
    // True for lessons that can't fully run on Azure SQL Database's free tier
    // (e.g. columnstore indexes require Standard S3+/Premium). Surfaced so the SPA
    // can show a clear note instead of a confusing runtime failure.
    public bool AzureUnsupported { get; set; }
}

// Deliberately a flat bag of optionals rather than a polymorphic hierarchy:
// adding a rule type stays additive and never breaks an existing manifest.
public sealed class RuleSpec
{
    public string Type { get; set; } = "";
    public string? Operator { get; set; }
    public string? Index { get; set; }
    public string? Table { get; set; }
    public string? Warning { get; set; }
    public double? Value { get; set; }
    // Design rules
    public string? Column { get; set; }
    public List<string>? Columns { get; set; }
    public string? References { get; set; }
    public string? Cardinality { get; set; }
    public string? Pattern { get; set; }
    public string? Scope { get; set; }
}

public sealed class ManifestReference
{
    public string Title { get; set; } = "";
    public string Url { get; set; } = "";
}

// A module's staged flow: read the concept, model it on the canvas, then run
// the SQL. Kinds are "read" | "canvas" | "sql".
public sealed class ModuleStep
{
    public string Kind { get; set; } = "read";
    public string? Prompt { get; set; }
    public string? Anchor { get; set; }
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
    public bool IsDesign => string.Equals(Manifest.Kind, "design", StringComparison.OrdinalIgnoreCase);
}

// ---------- API response DTOs (CONTRACT section 3) ----------

public sealed record HealthDto(string Status, string SqlServer, int LessonsLoaded);

public sealed record LevelDto(string Level, string Title, string Description, List<LessonSummaryDto> Lessons);

public sealed record TrackDto(
    string Key, string Title, string Description, int TotalLessons, int SolvedLessons);

public sealed record LessonSummaryDto(
    string Id, int Order, string Title, List<string> Topics, int EstimatedMinutes,
    bool IsConcurrency, bool Solved, int? BestLogicalReads, int? BestDurationMs, string Description,
    bool AzureUnsupported, string Track, string Kind);

public sealed record LessonDetailDto(
    string Id, string Level, string Title, List<string> Topics, int EstimatedMinutes,
    string Narrative, string StartingQuery, List<string> Hints, bool IsConcurrency,
    object? Interleaving, ProgressDto Progress, string Description, bool AzureUnsupported,
    string Track, string Kind);

public sealed record ProgressDto(bool Solved, int? BestLogicalReads, int? BestDurationMs, bool NewlySolved = false);

public sealed record SolutionDto(string Solution);

// A design module: everything LessonDetailDto carries, plus the canvas pieces.
public sealed record ModuleDetailDto(
    string Id, string Track, string Kind, string Level, string Title, string Description,
    List<string> Topics, int EstimatedMinutes, string Narrative, List<string> Hints,
    List<ModuleStep> Steps, ErdModel? StartingModel, ProgressDto Progress, bool AzureUnsupported);

public sealed record ModelSaveRequest(ErdModel Model);
public sealed record ModelDto(ErdModel? Model, DateTime? UpdatedAtUtc);

// The Check action: generate DDL from the model, run it, read the schema back,
// then grade. Ddl is echoed so the SPA can show exactly what ran.
public sealed record CheckRequest(ErdModel? Model, string? Sql);
public sealed record CheckResult(
    bool Success, string? Error, string Ddl, List<string> Warnings,
    SchemaDto? Schema, EvaluationDto? Evaluation, ProgressDto? Progress);

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

// Graded=false is a "scratch" run (e.g. running just an editor selection): it
// executes and returns plan/stats, but must never be evaluated or recorded as a
// solve. Grading a fragment is unsafe in both directions — per-table
// maxLogicalReads assumes the graded SELECT runs last in the batch, and
// resultUnchanged compares against a startingQuery baseline.
public sealed record RunRequest(string Sql, bool Graded = true);
public sealed record TutorChatRequest(string Message);

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

public sealed record SchemaColumnDto(
    string Name, string DataType, bool Nullable, bool IsIdentity, bool InPrimaryKey);

public sealed record SchemaIndexDto(
    string Name, string Type, bool IsUnique, bool IsPrimaryKey,
    string KeyColumns, string IncludedColumns, string? Filter);

// Cardinality is derived from metadata, not declared: a foreign key whose child
// columns are covered by a unique index or primary key can only ever match one
// parent row, which is what makes it one-to-one.
public sealed record SchemaForeignKeyDto(
    string Name, string Table, string Columns,
    string ReferencedTable, string ReferencedColumns,
    string OnDelete, string OnUpdate, bool IsDisabled, string Cardinality);

public sealed record SchemaTableDto(
    string Name, long RowCount,
    List<SchemaColumnDto> Columns, List<SchemaIndexDto> Indexes,
    List<SchemaForeignKeyDto> ForeignKeys, bool IsJunction);

public sealed record SchemaDto(string Schema, bool Seeded, List<SchemaTableDto> Tables);

public static class Json
{
    public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
    };
}
