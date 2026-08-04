using System.Text.RegularExpressions;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

/// <summary>
/// Grades a design module against the schema that actually exists in the
/// learner's database, after their DDL has run.
///
/// Grading the real database rather than the canvas is the central decision of
/// the design track. It cannot pass a diagram that would not build, and it is
/// implementation-agnostic: a learner who ignores the canvas and hand-writes
/// correct DDL passes just the same, which is pedagogically the right answer.
///
/// Note on normal forms: 2NF/3NF/BCNF are statements about functional
/// dependencies, which live in the problem domain and not in sys.columns. They
/// are graded here as the structural fingerprint of the correct decomposition
/// (this table exists, this column is gone from that one, this key connects
/// them) — never claim more than that in a module narrative.
/// </summary>
public static class DesignEvaluator
{
    public static EvaluationDto Evaluate(IReadOnlyList<RuleSpec> rules, SchemaDto schema)
    {
        var conditions = new List<ConditionResultDto>();
        foreach (var rule in rules)
        {
            var (label, passed, detail) = rule.Type switch
            {
                "entityExists" => EntityExists(rule, schema),
                "columnExists" => ColumnExists(rule, schema),
                "columnAbsent" => ColumnAbsent(rule, schema),
                "primaryKey" => PrimaryKey(rule, schema),
                "notNullable" => NotNullable(rule, schema),
                "hasDefault" => HasDefault(rule, schema),
                "checkConstraintExists" => CheckConstraintExists(rule, schema),
                "surrogateKey" => SurrogateKey(rule, schema),
                "naturalKeyUnique" => NaturalKeyUnique(rule, schema),
                "foreignKey" => ForeignKey(rule, schema),
                "indexOnFk" => IndexOnFk(rule, schema),
                "namingConvention" => NamingConvention(rule, schema),
                _ => ($"Unknown rule '{rule.Type}'", false, "unsupported")
            };
            conditions.Add(new ConditionResultDto(rule.Type, label, passed, detail));
        }
        return new EvaluationDto(conditions.Count > 0 && conditions.All(c => c.Passed), conditions);
    }

    private static (string, bool, string) EntityExists(RuleSpec r, SchemaDto s)
    {
        var t = Table(s, r.Table);
        return ($"Table {r.Table} exists", t is not null,
            t is not null ? $"{t.Columns.Count} columns" : "not found");
    }

    private static (string, bool, string) ColumnExists(RuleSpec r, SchemaDto s)
    {
        var t = Table(s, r.Table);
        var c = t?.Columns.FirstOrDefault(x => Eq(x.Name, r.Column));
        var label = $"{r.Table}.{r.Column} exists";
        if (c is null) return (label, false, t is null ? $"no table {r.Table}" : "column not found");

        // An expected type is optional: most modules care that the column is
        // there, not that it is exactly nvarchar(100).
        if (!string.IsNullOrWhiteSpace(r.Pattern) && !c.DataType.StartsWith(r.Pattern!, StringComparison.OrdinalIgnoreCase))
            return ($"{label} as {r.Pattern}", false, $"is {c.DataType}");
        return (label, true, c.DataType);
    }

    // The inverse of ColumnExists, and the rule normalization is graded on: a
    // decomposition is only real if the redundant column left the table it did
    // not belong in.
    //
    // A missing table fails rather than passes. "CourseTitle is absent from
    // Enrolment" is vacuously true when there is no Enrolment, and treating
    // that as a pass would reward deleting the table instead of decomposing it.
    private static (string, bool, string) ColumnAbsent(RuleSpec r, SchemaDto s)
    {
        var label = $"{r.Table}.{r.Column} no longer exists";

        // A negative rule with no column would match nothing and pass vacuously,
        // so an authoring slip would show up as a green module rather than a red
        // one. Every positive rule fails loudly in the same situation.
        if (string.IsNullOrWhiteSpace(r.Column))
            return ($"{r.Table}: columnAbsent rule has no column", false, "manifest error");

        var t = Table(s, r.Table);
        if (t is null) return (label, false, $"no table {r.Table}");

        var c = t.Columns.FirstOrDefault(x => Eq(x.Name, r.Column));
        return c is null
            ? (label, true, "moved out")
            : (label, false, $"still present as {c.DataType}");
    }

    // "This fact is required." Modules use it to check that moving columns into
    // their own table actually bought the stricter constraint that motivated it.
    private static (string, bool, string) NotNullable(RuleSpec r, SchemaDto s)
    {
        var t = Table(s, r.Table);
        var c = t?.Columns.FirstOrDefault(x => Eq(x.Name, r.Column));
        var label = $"{r.Table}.{r.Column} is NOT NULL";
        if (t is null) return (label, false, $"no table {r.Table}");
        if (c is null) return (label, false, "column not found");
        return (label, !c.Nullable, c.Nullable ? "is nullable" : "required");
    }

    // "This column fills itself in." A default is how NOT NULL stops being a
    // burden on every INSERT.
    private static (string, bool, string) HasDefault(RuleSpec r, SchemaDto s)
    {
        var t = Table(s, r.Table);
        var c = t?.Columns.FirstOrDefault(x => Eq(x.Name, r.Column));
        var label = $"{r.Table}.{r.Column} has a default";
        if (t is null) return (label, false, $"no table {r.Table}");
        if (c is null) return (label, false, "column not found");
        var has = !string.IsNullOrWhiteSpace(c.DefaultDefinition);
        return (label, has, has ? c.DefaultDefinition! : "no default");
    }

    // A CHECK on a named column, or anywhere on the table when no column is given.
    private static (string, bool, string) CheckConstraintExists(RuleSpec r, SchemaDto s)
    {
        var t = Table(s, r.Table);
        var label = r.Column is null
            ? $"{r.Table} has a CHECK constraint"
            : $"{r.Table}.{r.Column} has a CHECK constraint";
        if (t is null) return (label, false, $"no table {r.Table}");

        var hits = r.Column is null
            ? t.Checks
            : t.Checks.Where(c => Eq(c.Column, r.Column) ||
                                  c.Definition.Contains($"[{r.Column}]", StringComparison.OrdinalIgnoreCase)).ToList();
        return (label, hits.Count > 0, hits.Count > 0 ? hits[0].Definition : "none found");
    }

    private static (string, bool, string) PrimaryKey(RuleSpec r, SchemaDto s)
    {
        var t = Table(s, r.Table);
        if (t is null) return ($"{r.Table} has a primary key", false, $"no table {r.Table}");

        var actual = t.Columns.Where(c => c.InPrimaryKey).Select(c => c.Name).ToList();
        if (r.Columns is null or { Count: 0 })
            return ($"{r.Table} has a primary key", actual.Count > 0,
                actual.Count > 0 ? string.Join(", ", actual) : "none");

        var want = r.Columns.ToHashSet(StringComparer.OrdinalIgnoreCase);
        bool ok = want.SetEquals(actual);
        return ($"{r.Table} is keyed on {string.Join(", ", r.Columns)}", ok,
            actual.Count > 0 ? $"is {string.Join(", ", actual)}" : "no primary key");
    }

    // A surrogate key: one column, engine-generated, carrying no meaning. The
    // IDENTITY property is what distinguishes it from a single-column natural
    // key that merely happens to be an int.
    private static (string, bool, string) SurrogateKey(RuleSpec r, SchemaDto s)
    {
        var t = Table(s, r.Table);
        var label = $"{r.Table} has a surrogate key";
        if (t is null) return (label, false, $"no table {r.Table}");

        var pk = t.Columns.Where(c => c.InPrimaryKey).ToList();
        if (pk.Count == 0) return (label, false, "no primary key");
        if (pk.Count > 1) return (label, false, $"key is composite ({string.Join(", ", pk.Select(c => c.Name))})");
        return (label, pk[0].IsIdentity, pk[0].IsIdentity ? $"{pk[0].Name} IDENTITY" : $"{pk[0].Name} is not generated");
    }

    // The natural key is still enforced, just not used as the identifier —
    // a UNIQUE constraint rather than the primary key.
    private static (string, bool, string) NaturalKeyUnique(RuleSpec r, SchemaDto s)
    {
        var t = Table(s, r.Table);
        var cols = r.Columns is { Count: > 0 } ? r.Columns : (r.Column is null ? new List<string>() : new List<string> { r.Column });
        var label = $"{r.Table}({string.Join(", ", cols)}) is unique";
        if (t is null) return (label, false, $"no table {r.Table}");
        if (cols.Count == 0) return (label, false, "rule names no columns");

        var want = cols.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var hit = t.Indexes.FirstOrDefault(i =>
            i.IsUnique &&
            Split(i.KeyColumns).Select(StripDirection).ToHashSet(StringComparer.OrdinalIgnoreCase).SetEquals(want));
        return (label, hit is not null, hit is not null ? hit.Name : "no unique constraint on those columns");
    }

    private static (string, bool, string) ForeignKey(RuleSpec r, SchemaDto s)
    {
        var t = Table(s, r.Table);
        var label = $"{r.Table} references {r.References}";
        if (t is null) return (label, false, $"no table {r.Table}");

        var candidates = t.ForeignKeys.Where(f => Eq(f.ReferencedTable, r.References)).ToList();
        if (candidates.Count == 0)
            return (label, false, t.ForeignKeys.Count == 0 ? "no foreign keys on this table" : "no foreign key to that table");

        if (r.Columns is { Count: > 0 })
        {
            var want = r.Columns.ToHashSet(StringComparer.OrdinalIgnoreCase);
            candidates = candidates.Where(f => Split(f.Columns).ToHashSet(StringComparer.OrdinalIgnoreCase).SetEquals(want)).ToList();
            if (candidates.Count == 0)
                return ($"{label} on {string.Join(", ", r.Columns)}", false, "foreign key uses different columns");
        }

        if (!string.IsNullOrWhiteSpace(r.Cardinality))
        {
            var hit = candidates.FirstOrDefault(f => Eq(f.Cardinality, r.Cardinality));
            return ($"{label} ({Friendly(r.Cardinality!)})", hit is not null,
                hit is not null ? "as expected" : $"is {Friendly(candidates[0].Cardinality)}");
        }

        return (label, true, candidates[0].Columns);
    }

    private static (string, bool, string) IndexOnFk(RuleSpec r, SchemaDto s)
    {
        var t = Table(s, r.Table);
        var cols = r.Columns is { Count: > 0 } ? r.Columns : (r.Column is null ? new List<string>() : new List<string> { r.Column });
        var label = $"{r.Table}({string.Join(", ", cols)}) is indexed";
        if (t is null) return (label, false, $"no table {r.Table}");
        if (cols.Count == 0) return (label, false, "rule names no columns");

        // Leading-column match, not set equality: an index on (CustomerId,
        // OrderDate) does support seeking CustomerId.
        var want = cols.Select(c => c.Trim()).ToList();
        var hit = t.Indexes.FirstOrDefault(i =>
        {
            var keys = Split(i.KeyColumns).Select(StripDirection).ToList();
            return keys.Count >= want.Count && keys.Take(want.Count).SequenceEqual(want, StringComparer.OrdinalIgnoreCase);
        });
        return (label, hit is not null, hit is not null ? hit.Name : "no index leads with those columns");
    }

    private static (string, bool, string) NamingConvention(RuleSpec r, SchemaDto s)
    {
        var pattern = r.Pattern ?? "PascalCase";
        var regex = pattern switch
        {
            "PascalCase" => "^[A-Z][A-Za-z0-9]*$",
            "camelCase" => "^[a-z][A-Za-z0-9]*$",
            "snake_case" => "^[a-z][a-z0-9_]*$",
            _ => pattern,
        };

        var scope = r.Scope ?? "tables";
        var names = scope switch
        {
            "columns" => s.Tables.SelectMany(t => t.Columns.Select(c => $"{t.Name}.{c.Name}")).ToList(),
            "all" => s.Tables.Select(t => t.Name)
                        .Concat(s.Tables.SelectMany(t => t.Columns.Select(c => $"{t.Name}.{c.Name}"))).ToList(),
            _ => s.Tables.Select(t => t.Name).ToList(),
        };

        var bad = names.Where(n => !Regex.IsMatch(n.Split('.').Last(), regex)).ToList();
        var label = $"{Capitalize(scope)} follow {pattern}";
        if (names.Count == 0) return (label, false, "nothing to check yet");
        return (label, bad.Count == 0, bad.Count == 0 ? $"{names.Count} checked" : $"offenders: {string.Join(", ", bad.Take(3))}");
    }

    private static SchemaTableDto? Table(SchemaDto s, string? name) =>
        s.Tables.FirstOrDefault(t => Eq(t.Name, name));

    private static IEnumerable<string> Split(string cols) =>
        cols.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static string StripDirection(string keyCol)
    {
        var s = keyCol.Trim();
        if (s.EndsWith(" ASC", StringComparison.OrdinalIgnoreCase)) return s[..^4].Trim();
        if (s.EndsWith(" DESC", StringComparison.OrdinalIgnoreCase)) return s[..^5].Trim();
        return s;
    }

    private static string Friendly(string cardinality) => cardinality switch
    {
        "oneToOne" => "one-to-one",
        "manyToOne" => "many-to-one",
        "manyToMany" => "many-to-many",
        _ => cardinality,
    };

    private static string Capitalize(string s) => s.Length == 0 ? s : char.ToUpperInvariant(s[0]) + s[1..];

    private static bool Eq(string? a, string? b) => string.Equals(a, b, StringComparison.OrdinalIgnoreCase);
}
