using System.Text;
using System.Text.RegularExpressions;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

/// <summary>
/// Turns a canvas model into T-SQL.
///
/// Server-side rather than in the SPA on purpose: the /check endpoint needs it
/// anyway, it is pure and testable, and the T-SQL type and quoting knowledge
/// belongs in one place.
///
/// The output is always shown to the learner before it runs. That is a teaching
/// decision as much as a safety one — a generator bug then looks like visibly
/// wrong SQL rather than a mysteriously failed check.
/// </summary>
public static partial class DdlGenerator
{
    public sealed class InvalidModelException(string message) : Exception(message);

    [GeneratedRegex(@"^[A-Za-z_][A-Za-z0-9_]{0,127}$")]
    private static partial Regex IdentifierRegex();

    // A canvas name reaches EXEC, so this is a security control, not tidiness.
    // Reject rather than escape: a name that needs escaping is a name the
    // learner did not mean to type.
    public static string Ident(string? name)
    {
        var n = (name ?? "").Trim();
        if (!IdentifierRegex().IsMatch(n))
            throw new InvalidModelException(
                $"'{name}' is not a valid SQL identifier. Use letters, digits and underscores, starting with a letter or underscore.");
        return $"[{n}]";
    }

    // Types are matched against a fixed list rather than passed through, for the
    // same reason as identifiers.
    private static readonly HashSet<string> BaseTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "int", "bigint", "smallint", "tinyint", "bit", "decimal", "numeric", "money", "float", "real",
        "date", "datetime2", "datetime", "datetimeoffset", "time",
        "char", "varchar", "nchar", "nvarchar", "uniqueidentifier", "varbinary",
    };

    [GeneratedRegex(@"^([A-Za-z0-9_]+)\s*(\(\s*(max|\d+(\s*,\s*\d+)?)\s*\))?$", RegexOptions.IgnoreCase)]
    private static partial Regex TypeRegex();

    public static string DataType(string? type)
    {
        var t = (type ?? "").Trim();
        var m = TypeRegex().Match(t);
        if (!m.Success || !BaseTypes.Contains(m.Groups[1].Value))
            throw new InvalidModelException($"'{type}' is not a supported data type.");
        return t;
    }

    public static DdlResponse Generate(ErdModel model)
    {
        var warnings = new List<string>();
        var sb = new StringBuilder();
        var byId = model.Entities.ToDictionary(e => e.Id, StringComparer.Ordinal);

        // Emission order — every table, then every foreign key, then indexes —
        // means declaration order never matters. This is how migration tools do
        // it, and it removes a whole class of "table not found" failures.
        foreach (var e in model.Entities.OrderBy(e => e.Name, StringComparer.OrdinalIgnoreCase))
        {
            if (e.Attributes.Count == 0)
            {
                warnings.Add($"{e.Name} has no columns and was skipped.");
                continue;
            }

            sb.Append("CREATE TABLE ").Append(Ident(e.Name)).AppendLine(" (");
            var lines = new List<string>();
            foreach (var a in e.Attributes)
            {
                var identity = a.IsIdentity ? " IDENTITY(1,1)" : "";
                var nullability = a.Nullable && !a.IsPrimaryKey ? "NULL" : "NOT NULL";
                lines.Add($"    {Ident(a.Name)} {DataType(a.DataType)}{identity} {nullability}");
            }

            var pk = e.Attributes.Where(a => a.IsPrimaryKey).ToList();
            if (pk.Count > 0)
                lines.Add($"    CONSTRAINT {Ident("PK_" + e.Name)} PRIMARY KEY ({string.Join(", ", pk.Select(a => Ident(a.Name)))})");
            else
                warnings.Add($"{e.Name} has no primary key.");

            // A unique constraint per flagged column: this is how a natural key
            // is expressed when the table is keyed on a surrogate instead.
            foreach (var u in e.Attributes.Where(a => a.IsUnique && !a.IsPrimaryKey))
                lines.Add($"    CONSTRAINT {Ident($"UQ_{e.Name}_{u.Name}")} UNIQUE ({Ident(u.Name)})");

            sb.AppendLine(string.Join(",\n", lines)).AppendLine(");").AppendLine();
        }

        // Many-to-many has no direct representation in DDL: it becomes a
        // junction table keyed by both sides, which is the point of the lesson.
        foreach (var rel in model.Relationships.Where(IsManyToMany))
        {
            if (!byId.TryGetValue(rel.FromEntityId, out var from) || !byId.TryGetValue(rel.ToEntityId, out var to))
                continue;
            var name = from.Name + to.Name;
            var fromKey = KeyColumns(from);
            var toKey = KeyColumns(to);
            if (fromKey.Count == 0 || toKey.Count == 0)
            {
                warnings.Add($"Cannot build the junction table for {from.Name} ↔ {to.Name}: both sides need a primary key.");
                continue;
            }

            // The two sides can carry the same key name (two tables keyed "Id"),
            // so disambiguate by prefixing with the table it points at.
            var fromNames = fromKey.Select(a => a.Name).ToList();
            var toNames = toKey.Select(a => a.Name).ToList();
            if (fromNames.Intersect(toNames, StringComparer.OrdinalIgnoreCase).Any())
            {
                fromNames = fromKey.Select(a => from.Name + a.Name).ToList();
                toNames = toKey.Select(a => to.Name + a.Name).ToList();
            }

            sb.Append("CREATE TABLE ").Append(Ident(name)).AppendLine(" (");
            var cols = fromKey.Zip(fromNames).Concat(toKey.Zip(toNames)).ToList();
            var colLines = cols.Select(p => $"    {Ident(p.Second)} {DataType(p.First.DataType)} NOT NULL").ToList();
            colLines.Add($"    CONSTRAINT {Ident("PK_" + name)} PRIMARY KEY ({string.Join(", ", cols.Select(p => Ident(p.Second)))})");
            sb.AppendLine(string.Join(",\n", colLines)).AppendLine(");").AppendLine();

            sb.AppendLine(Fk(name, fromNames, from.Name, fromKey.Select(a => a.Name), "NO ACTION"));
            sb.AppendLine(Fk(name, toNames, to.Name, toKey.Select(a => a.Name), "NO ACTION"));
            sb.AppendLine();
        }

        foreach (var rel in model.Relationships.Where(r => !IsManyToMany(r)))
        {
            if (!byId.TryGetValue(rel.FromEntityId, out var child) || !byId.TryGetValue(rel.ToEntityId, out var parent))
                continue;
            var childCols = rel.FromColumns.Count > 0 ? rel.FromColumns : KeyColumns(parent).Select(a => a.Name).ToList();
            var parentCols = rel.ToColumns.Count > 0 ? rel.ToColumns : KeyColumns(parent).Select(a => a.Name).ToList();
            if (childCols.Count == 0 || childCols.Count != parentCols.Count)
            {
                warnings.Add($"Skipped the {child.Name} → {parent.Name} relationship: its columns don't line up.");
                continue;
            }
            sb.AppendLine(Fk(child.Name, childCols, parent.Name, parentCols, ReferentialAction(rel.OnDelete)));

            // SQL Server does not index foreign keys automatically. Creating the
            // index here is deliberate: it is the single most common omission in
            // a hand-built schema, and the design track teaches why it matters.
            var idxName = $"IX_{child.Name}_{string.Join("_", childCols)}";
            var unique = string.Equals(rel.Cardinality, "oneToOne", StringComparison.OrdinalIgnoreCase) ? "UNIQUE " : "";
            sb.Append("CREATE ").Append(unique).Append("INDEX ").Append(Ident(idxName))
              .Append(" ON ").Append(Ident(child.Name))
              .Append(" (").Append(string.Join(", ", childCols.Select(Ident))).AppendLine(");");
            sb.AppendLine();
        }

        return new DdlResponse(sb.ToString().TrimEnd() + "\n", warnings);
    }

    private static string Fk(string child, IEnumerable<string> childCols, string parent, IEnumerable<string> parentCols, string onDelete)
    {
        var cc = childCols.ToList();
        var name = $"FK_{child}_{parent}";
        return $"ALTER TABLE {Ident(child)} ADD CONSTRAINT {Ident(name)} " +
               $"FOREIGN KEY ({string.Join(", ", cc.Select(Ident))}) " +
               $"REFERENCES {Ident(parent)} ({string.Join(", ", parentCols.Select(Ident))})" +
               (onDelete == "NO ACTION" ? ";" : $" ON DELETE {onDelete};");
    }

    private static string ReferentialAction(string? action) => (action ?? "").Trim().ToUpperInvariant() switch
    {
        "CASCADE" => "CASCADE",
        "SET NULL" => "SET NULL",
        "SET DEFAULT" => "SET DEFAULT",
        _ => "NO ACTION",
    };

    private static bool IsManyToMany(ErdRelationship r) =>
        string.Equals(r.Cardinality, "manyToMany", StringComparison.OrdinalIgnoreCase);

    private static List<ErdAttribute> KeyColumns(ErdEntity e) =>
        e.Attributes.Where(a => a.IsPrimaryKey).ToList();
}
