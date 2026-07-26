using System.Xml.Linq;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

// Parses SQL Server ShowPlanXML into the simplified PlanNode tree + plan-level warnings.
// Namespace-agnostic (matches on local names) to be resilient across SQL Server versions.
public sealed record ParsedPlan(PlanDto Dto, double RootCost);

public static class PlanParser
{
    public static ParsedPlan? Parse(string? showPlanXml)
    {
        if (string.IsNullOrWhiteSpace(showPlanXml)) return null;
        XDocument doc;
        try { doc = XDocument.Parse(showPlanXml); }
        catch { return null; }

        // First statement's query plan (lessons run a single meaningful statement).
        var queryPlan = Descendants(doc.Root, "QueryPlan").FirstOrDefault();
        var rootRelOp = queryPlan is null ? null : ChildRelOps(queryPlan).FirstOrDefault();

        double rootCost = rootRelOp is null ? 0 : SubtreeCost(rootRelOp);
        var node = rootRelOp is null ? null : BuildNode(rootRelOp, rootCost);

        var warnings = new List<PlanWarning>();
        var missing = new List<MissingIndexDto>();

        if (queryPlan is not null)
        {
            foreach (var grp in Descendants(queryPlan, "MissingIndexGroup"))
            {
                var impact = ParseD(grp.Attribute("Impact")?.Value);
                foreach (var mi in Descendants(grp, "MissingIndex"))
                {
                    var stmt = BuildCreateIndex(mi);
                    missing.Add(new MissingIndexDto(impact, stmt));
                    warnings.Add(new PlanWarning("MissingIndex", impact, stmt));
                }
            }
        }

        // Aggregate node-level warnings to plan level for the UI warning strip.
        if (node is not null)
            CollectWarnings(node, warnings);

        return new ParsedPlan(new PlanDto(node, warnings, missing), rootCost);
    }

    private static void CollectWarnings(PlanNode n, List<PlanWarning> acc)
    {
        foreach (var w in n.Warnings)
            if (!acc.Any(x => x.Type == w))
                acc.Add(new PlanWarning(w, 0, $"{n.PhysicalOp}"));
        foreach (var c in n.Children) CollectWarnings(c, acc);
    }

    private static PlanNode BuildNode(XElement relOp, double rootCost)
    {
        var node = new PlanNode
        {
            NodeId = (int)ParseD(relOp.Attribute("NodeId")?.Value),
            PhysicalOp = relOp.Attribute("PhysicalOp")?.Value ?? "",
            LogicalOp = relOp.Attribute("LogicalOp")?.Value ?? "",
            EstimateRows = ParseD(relOp.Attribute("EstimateRows")?.Value),
            Object = FindObject(relOp),
        };

        var children = ChildRelOps(relOp).ToList();
        double subtree = SubtreeCost(relOp);
        double childrenCost = children.Sum(SubtreeCost);
        double ownCost = Math.Max(0, subtree - childrenCost);
        node.EstimatedCostPercent = rootCost > 0 ? Math.Round(ownCost / rootCost * 100, 1) : 0;

        // Actual rows: sum ActualRows across this RelOp's own RunTimeCountersPerThread.
        var counters = OwnedDescendants(relOp, "RunTimeCountersPerThread").ToList();
        if (counters.Count > 0)
            node.ActualRows = counters.Sum(c => ParseD(c.Attribute("ActualRows")?.Value));

        // Node warnings.
        foreach (var wc in OwnedDescendants(relOp, "Warnings"))
        {
            // Some warnings are attributes on <Warnings> itself (e.g. NoJoinPredicate="1"),
            // not child elements.
            var njp = wc.Attribute("NoJoinPredicate")?.Value;
            if (njp is "1" or "true") node.Warnings.Add("NoJoinPredicate");

            foreach (var child in wc.Elements())
            {
                var name = child.Name.LocalName;
                if (name == "PlanAffectingConvert") node.Warnings.Add("ImplicitConversion");
                else if (name is "SpillToTempDb") node.Warnings.Add("SpillToTempDb");
                else if (name is "ColumnsWithNoStatistics") node.Warnings.Add("ColumnsWithNoStatistics");
                else if (name is "NoJoinPredicate") node.Warnings.Add("NoJoinPredicate");
                else node.Warnings.Add(name);
            }
        }
        node.Warnings = node.Warnings.Distinct().ToList();

        foreach (var c in children) node.Children.Add(BuildNode(c, rootCost));
        return node;
    }

    private static string? FindObject(XElement relOp)
    {
        // Nearest Object element owned by this RelOp (not a nested one).
        var obj = OwnedDescendants(relOp, "Object").FirstOrDefault();
        if (obj is null) return null;
        var table = Trim(obj.Attribute("Table")?.Value);
        var index = Trim(obj.Attribute("Index")?.Value);
        if (table is null && index is null) return null;
        return index is null ? table : $"{table}.{index}";
    }

    private static string BuildCreateIndex(XElement missingIndex)
    {
        var table = Trim(missingIndex.Attribute("Table")?.Value) ?? "table";
        var eq = new List<string>();
        var ineq = new List<string>();
        var incl = new List<string>();
        foreach (var grp in Descendants(missingIndex, "ColumnGroup"))
        {
            var usage = grp.Attribute("Usage")?.Value;
            var cols = Descendants(grp, "Column").Select(c => Trim(c.Attribute("Name")?.Value) ?? "").Where(s => s != "");
            if (usage == "EQUALITY") eq.AddRange(cols);
            else if (usage == "INEQUALITY") ineq.AddRange(cols);
            else if (usage == "INCLUDE") incl.AddRange(cols);
        }
        var keys = string.Join(", ", eq.Concat(ineq));
        var include = incl.Count > 0 ? $" INCLUDE ({string.Join(", ", incl)})" : "";
        return $"CREATE NONCLUSTERED INDEX IX_Missing ON {table} ({keys}){include}";
    }

    // ---- XML helpers (namespace-agnostic) ----

    private static double SubtreeCost(XElement relOp) =>
        ParseD(relOp.Attribute("EstimatedTotalSubtreeCost")?.Value);

    private static IEnumerable<XElement> Descendants(XElement? e, string local) =>
        e is null ? Enumerable.Empty<XElement>() : e.Descendants().Where(x => x.Name.LocalName == local);

    // Immediate child RelOp elements (descendants with no intervening RelOp).
    private static IEnumerable<XElement> ChildRelOps(XElement e) =>
        OwnedDescendants(e, "RelOp");

    // Descendants of the given local name that belong to `e` and are not nested under
    // an intervening RelOp boundary (so per-node data isn't double-counted).
    private static IEnumerable<XElement> OwnedDescendants(XElement e, string local)
    {
        foreach (var child in e.Elements())
            foreach (var found in Walk(child, local))
                yield return found;

        static IEnumerable<XElement> Walk(XElement node, string local)
        {
            if (node.Name.LocalName == local) { yield return node; yield break; }
            if (node.Name.LocalName == "RelOp") yield break; // boundary
            foreach (var c in node.Elements())
                foreach (var f in Walk(c, local))
                    yield return f;
        }
    }

    private static double ParseD(string? s) =>
        double.TryParse(s, System.Globalization.NumberStyles.Any,
            System.Globalization.CultureInfo.InvariantCulture, out var d) ? d : 0;

    private static string? Trim(string? s) => string.IsNullOrEmpty(s) ? null : s.Trim('[', ']');
}
