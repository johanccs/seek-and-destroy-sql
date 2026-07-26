using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

// Implements the pass-condition rule vocabulary (CONTRACT section 4).
public static class Evaluator
{
    public static EvaluationDto EvaluateQuery(
        IReadOnlyList<RuleSpec> rules, PlanDto? plan, double rootCost,
        StatsDto? stats, IReadOnlyList<ResultSetDto> results, string baselineSignature)
    {
        var conditions = new List<ConditionResultDto>();
        var nodes = plan?.Root is null ? new List<PlanNode>() : Flatten(plan.Root).ToList();

        foreach (var rule in rules)
        {
            var (label, passed, detail) = rule.Type switch
            {
                "noOperator" => NoOperator(rule, nodes),
                "requireOperator" => RequireOperator(rule, nodes),
                "indexUsed" => IndexUsed(rule, nodes),
                "maxLogicalReads" => MaxLogicalReads(rule, stats),
                "maxDurationMs" => MaxDuration(rule, stats),
                "maxEstimatedCost" => MaxEstimatedCost(rule, rootCost),
                "noWarning" => NoWarning(rule, plan, nodes),
                "rowCountEquals" => RowCountEquals(rule, results),
                "resultUnchanged" => ResultUnchanged(results, baselineSignature),
                _ => ($"Unknown rule '{rule.Type}'", false, "unsupported")
            };
            conditions.Add(new ConditionResultDto(rule.Type, label, passed, detail));
        }

        return new EvaluationDto(conditions.All(c => c.Passed), conditions);
    }

    public static EvaluationDto EvaluateConcurrency(IReadOnlyList<RuleSpec> rules, ConcurrencyResult r)
    {
        var conditions = new List<ConditionResultDto>();
        foreach (var rule in rules)
        {
            var (label, passed, detail) = rule.Type switch
            {
                "noDeadlock" => ("No deadlock occurs", r.Outcome != "deadlock", $"outcome={r.Outcome}"),
                "bothCommit" => ("Both sessions commit", r.Outcome == "completed", $"outcome={r.Outcome}"),
                "maxBlockMs" => MaxBlock(rule, r),
                _ => ($"Unknown rule '{rule.Type}'", false, "unsupported")
            };
            conditions.Add(new ConditionResultDto(rule.Type, label, passed, detail));
        }
        return new EvaluationDto(conditions.All(c => c.Passed), conditions);
    }

    // ---- query rules ----

    private static (string, bool, string) NoOperator(RuleSpec r, List<PlanNode> nodes)
    {
        var op = r.Operator ?? "";
        var hit = nodes.FirstOrDefault(n => Eq(n.PhysicalOp, op) || Eq(n.LogicalOp, op));
        return ($"No {op} in plan", hit is null, hit is null ? "not present" : $"found node {hit.NodeId}");
    }

    private static (string, bool, string) RequireOperator(RuleSpec r, List<PlanNode> nodes)
    {
        var op = r.Operator ?? "";
        var hit = nodes.FirstOrDefault(n => Eq(n.PhysicalOp, op) || Eq(n.LogicalOp, op));
        return ($"Plan uses {op}", hit is not null, hit is not null ? $"node {hit.NodeId}" : "not present");
    }

    private static (string, bool, string) IndexUsed(RuleSpec r, List<PlanNode> nodes)
    {
        var idx = r.Index ?? "";
        var hit = nodes.FirstOrDefault(n => n.Object is not null &&
            n.Object.Contains(idx, StringComparison.OrdinalIgnoreCase));
        return ($"Index {idx} is used", hit is not null,
            hit is not null ? $"{hit.PhysicalOp} on {hit.Object}" : "not referenced");
    }

    private static (string, bool, string) MaxLogicalReads(RuleSpec r, StatsDto? stats)
    {
        int limit = (int)(r.Value ?? 0);
        if (stats is null) return ($"Logical reads ≤ {limit}", false, "no stats");
        int actual = r.Table is null
            ? stats.TotalLogicalReads
            : stats.PerTable.Where(p => Eq(p.Table, r.Table)).Sum(p => p.LogicalReads);
        var scope = r.Table is null ? "total" : r.Table;
        return ($"Logical reads on {scope} ≤ {limit}", actual <= limit, $"{actual} reads");
    }

    private static (string, bool, string) MaxDuration(RuleSpec r, StatsDto? stats)
    {
        int limit = (int)(r.Value ?? 0);
        int actual = stats?.ElapsedTimeMs ?? int.MaxValue;
        return ($"Elapsed time ≤ {limit} ms", actual <= limit, $"{actual} ms");
    }

    private static (string, bool, string) MaxEstimatedCost(RuleSpec r, double rootCost)
    {
        double limit = r.Value ?? 0;
        return ($"Estimated cost ≤ {limit}", rootCost <= limit, $"{rootCost:0.####}");
    }

    private static (string, bool, string) NoWarning(RuleSpec r, PlanDto? plan, List<PlanNode> nodes)
    {
        var w = r.Warning ?? "";
        bool present = (plan?.Warnings.Any(x => Eq(x.Type, w)) ?? false)
            || nodes.Any(n => n.Warnings.Any(x => Eq(x, w)));
        return ($"No {w} warning", !present, present ? "present" : "absent");
    }

    private static (string, bool, string) RowCountEquals(RuleSpec r, IReadOnlyList<ResultSetDto> results)
    {
        int expected = (int)(r.Value ?? 0);
        int actual = results.Sum(rs => rs.RowCount);
        return ($"Returns {expected} rows", actual == expected, $"{actual} rows");
    }

    private static (string, bool, string) ResultUnchanged(IReadOnlyList<ResultSetDto> results, string baseline)
    {
        var data = results.FirstOrDefault(rs => rs.Columns.Count > 0);
        var sig = SqlExecutor.SignatureOf(data);
        bool ok = !string.IsNullOrEmpty(baseline) && sig == baseline;
        return ("Result matches baseline", ok, ok ? "identical" : "differs from baseline");
    }

    private static (string, bool, string) MaxBlock(RuleSpec r, ConcurrencyResult res)
    {
        int limit = (int)(r.Value ?? 0);
        var blocked = res.Timeline.Where(e => e.Event == "blocked").ToList();
        var resolved = res.Timeline.Where(e => e.Event is "acquired" or "commit" or "deadlock-victim").ToList();
        int maxBlock = 0;
        foreach (var b in blocked)
        {
            var end = resolved.Where(e => e.Session == b.Session && e.TMs >= b.TMs)
                .Select(e => e.TMs).DefaultIfEmpty(b.TMs).Min();
            maxBlock = Math.Max(maxBlock, end - b.TMs);
        }
        return ($"No block longer than {limit} ms", maxBlock <= limit, $"max block {maxBlock} ms");
    }

    private static IEnumerable<PlanNode> Flatten(PlanNode n)
    {
        yield return n;
        foreach (var c in n.Children)
            foreach (var d in Flatten(c))
                yield return d;
    }

    private static bool Eq(string? a, string? b) =>
        string.Equals(a, b, StringComparison.OrdinalIgnoreCase);
}
