namespace SqlPerf.Api.Models;

// The canvas model. Deliberately a plain serialisable shape with no dependency
// on the rendering library the SPA happens to use: the DDL generator, the
// grader and the saved-diagram store all read this, never React Flow's types.
public sealed class ErdModel
{
    public List<ErdEntity> Entities { get; set; } = new();
    public List<ErdRelationship> Relationships { get; set; } = new();
}

public sealed class ErdEntity
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public double X { get; set; }
    public double Y { get; set; }
    public List<ErdAttribute> Attributes { get; set; } = new();
}

public sealed class ErdAttribute
{
    public string Name { get; set; } = "";
    public string DataType { get; set; } = "int";
    public bool Nullable { get; set; }
    public bool IsPrimaryKey { get; set; }
    public bool IsIdentity { get; set; }
    // A natural key: unique, but not the row's identifier. Emitted as a UNIQUE
    // constraint, which is how you say "no two rows may share this value"
    // without making it the primary key.
    public bool IsUnique { get; set; }
}

public sealed class ErdRelationship
{
    public string Id { get; set; } = "";
    // The child (the side that carries the foreign key) and the parent.
    public string FromEntityId { get; set; } = "";
    public string ToEntityId { get; set; } = "";
    public List<string> FromColumns { get; set; } = new();
    public List<string> ToColumns { get; set; } = new();
    // manyToOne | oneToOne | manyToMany. manyToMany has no direct DDL form and
    // is emitted as a junction table.
    public string Cardinality { get; set; } = "manyToOne";
    public string OnDelete { get; set; } = "NO ACTION";
}

public sealed record DdlRequest(ErdModel Model);
public sealed record DdlResponse(string Ddl, List<string> Warnings);
