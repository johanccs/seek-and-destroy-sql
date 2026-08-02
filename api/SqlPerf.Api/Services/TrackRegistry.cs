namespace SqlPerf.Api.Services;

public sealed record TrackLevel(string Key, string Title, string Description);

public sealed record Track(string Key, string Title, string Description, IReadOnlyList<TrackLevel> Levels);

// The curriculum tracks and their level copy. This used to be a bare array of
// level titles inline in Program.cs, which worked only while there was exactly
// one curriculum. Lessons declare which track they belong to via their manifest.
public sealed class TrackRegistry
{
    public const string Perf = "perf";
    public const string Design = "design";

    private readonly Dictionary<string, Track> _byKey;

    public TrackRegistry()
    {
        var tracks = new[]
        {
            new Track(Perf, "SQL Performance",
                "Tune real T-SQL against a live SQL Server engine — indexes, plan reading, concurrency, and the engine internals behind them.",
                new[]
                {
                    new TrackLevel("beginner", "Beginner",
                        "The fundamentals of making SQL Server fast: how indexes turn scans into seeks, why wrapping a column in a function or the wrong data type quietly disables an index, and how to cover, order, and range-search your data. Master these and you'll fix the majority of everyday slow queries."),
                    new TrackLevel("intermediate", "Intermediate",
                        "Sharper indexing and query-shape skills: covering and composite indexes, filtered indexes, key ordering, keyset pagination, sargable rewrites, implicit-conversion traps on joins, and turning accidental Cartesian products and EXISTS/aggregate patterns into efficient plans."),
                    new TrackLevel("advanced", "Advanced",
                        "Where the optimizer and the engine get subtle: parameter sniffing, stale statistics, tipping points, heaps and RID lookups, anti-joins, catch-all queries, and a full arc of concurrency — blocking, deadlocks, lock escalation, isolation levels, and snapshot conflicts — validated against a real two-session engine."),
                    new TrackLevel("expert", "Expert",
                        "Deep engine internals and analytics: scalar-UDF and window-function costs, columnstore and batch mode, partitioning, compression, tempdb spills and memory grants, worktable spools, RANGE-vs-ROWS frames, top-N-per-group, and reading the plan's own warnings and missing-index hints."),
                }),

            new Track(Design, "Database Design",
                "Model schemas on an interactive canvas, then build them for real — relationships, normalization, indexing strategy, and the trade-offs behind each decision.",
                new[]
                {
                    new TrackLevel("beginner", "Beginner",
                        "How to turn a problem description into tables: entities and attributes, choosing data types that don't cost you later, primary keys (and when a natural key beats a surrogate), the three relationship shapes and how each is actually stored, and constraints as executable documentation. You'll draw each model and then build it against a live engine."),
                    new TrackLevel("intermediate", "Intermediate",
                        "Normalization, taught as anomaly-removal rather than rule-following: the update, insert, and delete anomalies that motivate each normal form, then 1NF through BCNF applied to models you decompose yourself — plus when to denormalize on purpose and how to keep that decision honest."),
                    new TrackLevel("advanced", "Advanced",
                        "Design decisions the optimizer can see: how indexes are physically stored, choosing a clustered key, covering and composite indexes for a stated workload, the deadlock and delete-plan cost of unindexed foreign keys, write amplification from over-indexing, and the constraints the optimizer actually trusts and uses."),
                    new TrackLevel("expert", "Expert",
                        "Where design meets the wider system: stored procedures as an interface boundary, the real cost of scalar UDFs against inline table-valued functions, triggers and their failure modes, temporal and slowly-changing history, OLTP against OLAP shapes for the same data, and a gallery of anti-patterns with the numbers that condemn them."),
                }),
        };

        _byKey = tracks.ToDictionary(t => t.Key, StringComparer.OrdinalIgnoreCase);
    }

    public IReadOnlyCollection<Track> All => _byKey.Values;

    // An unknown or missing key resolves to the performance track: /api/levels
    // predates tracks and callers of it must keep working unchanged.
    public Track Resolve(string? key) =>
        key is not null && _byKey.TryGetValue(key, out var t) ? t : _byKey[Perf];

    public Track? Find(string? key) =>
        key is not null && _byKey.TryGetValue(key, out var t) ? t : null;
}
