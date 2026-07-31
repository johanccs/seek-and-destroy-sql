using Microsoft.Data.SqlClient;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

/// <summary>
/// Reads table/column/index metadata for a lesson's schema.
///
/// Deliberately separate from SqlExecutor and always on its own connection:
/// SqlExecutor wraps user SQL in SET STATISTICS IO/TIME/XML and the grader parses
/// those results, so metadata reads sharing that connection would corrupt the
/// logical-read counts maxLogicalReads grades on.
/// </summary>
public sealed class SchemaReader
{
    private readonly string _cs;

    public SchemaReader(IConfiguration cfg)
    {
        var baseCs = cfg.GetConnectionString("Sql")!;
        var db = cfg["Sql:AppDatabase"] ?? "SqlPerfDb";
        _cs = new SqlConnectionStringBuilder(baseCs) { InitialCatalog = db }.ConnectionString;
    }

    public async Task<SchemaDto> ReadAsync(string schema)
    {
        await using var c = new SqlConnection(_cs);
        await c.OpenAsync();

        var tables = new Dictionary<int, SchemaTableRow>();

        // ---- tables + row counts ----
        const string tablesSql = @"
SELECT t.object_id, t.name,
       ISNULL((SELECT SUM(ps.row_count) FROM sys.dm_db_partition_stats ps
               WHERE ps.object_id = t.object_id AND ps.index_id IN (0,1)), 0) AS row_count
FROM sys.tables t
WHERE t.schema_id = SCHEMA_ID(@schema)
ORDER BY t.name;";
        await using (var cmd = new SqlCommand(tablesSql, c))
        {
            cmd.Parameters.AddWithValue("@schema", schema);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
                tables[r.GetInt32(0)] = new SchemaTableRow(r.GetString(1), Convert.ToInt64(r.GetValue(2)));
        }
        if (tables.Count == 0) return new SchemaDto(schema, true, new List<SchemaTableDto>());

        // ---- columns ----
        const string colsSql = @"
SELECT c.object_id, c.name, ty.name AS type_name, c.max_length, c.precision, c.scale,
       c.is_nullable, c.is_identity,
       CAST(CASE WHEN EXISTS (
            SELECT 1 FROM sys.indexes i
            JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
            WHERE i.object_id = c.object_id AND i.is_primary_key = 1 AND ic.column_id = c.column_id
       ) THEN 1 ELSE 0 END AS bit) AS in_pk
FROM sys.columns c
JOIN sys.tables t ON t.object_id = c.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE t.schema_id = SCHEMA_ID(@schema)
ORDER BY c.object_id, c.column_id;";
        await using (var cmd = new SqlCommand(colsSql, c))
        {
            cmd.Parameters.AddWithValue("@schema", schema);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                var id = r.GetInt32(0);
                if (!tables.TryGetValue(id, out var t)) continue;
                t.Columns.Add(new SchemaColumnDto(
                    r.GetString(1),
                    FormatType(r.GetString(2), r.GetInt16(3), r.GetByte(4), r.GetByte(5)),
                    r.GetBoolean(6), r.GetBoolean(7), r.GetBoolean(8)));
            }
        }

        // ---- indexes ----
        const string idxSql = @"
SELECT i.object_id, i.name, i.type_desc, i.is_unique, i.is_primary_key, i.filter_definition,
       STUFF((SELECT ', ' + c2.name + CASE WHEN ic2.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
              FROM sys.index_columns ic2
              JOIN sys.columns c2 ON c2.object_id = ic2.object_id AND c2.column_id = ic2.column_id
              WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id AND ic2.is_included_column = 0
              ORDER BY ic2.key_ordinal
              FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, '') AS key_cols,
       ISNULL(STUFF((SELECT ', ' + c3.name
              FROM sys.index_columns ic3
              JOIN sys.columns c3 ON c3.object_id = ic3.object_id AND c3.column_id = ic3.column_id
              WHERE ic3.object_id = i.object_id AND ic3.index_id = i.index_id AND ic3.is_included_column = 1
              ORDER BY c3.name
              FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, ''), '') AS inc_cols
FROM sys.indexes i
JOIN sys.tables t ON t.object_id = i.object_id
WHERE t.schema_id = SCHEMA_ID(@schema) AND i.type <> 0 AND i.name IS NOT NULL
ORDER BY i.object_id, i.is_primary_key DESC, i.name;";
        await using (var cmd = new SqlCommand(idxSql, c))
        {
            cmd.Parameters.AddWithValue("@schema", schema);
            await using var r = await cmd.ExecuteReaderAsync();
            while (await r.ReadAsync())
            {
                var id = r.GetInt32(0);
                if (!tables.TryGetValue(id, out var t)) continue;
                t.Indexes.Add(new SchemaIndexDto(
                    r.GetString(1),
                    r.GetString(2).Replace('_', ' '),
                    r.GetBoolean(3), r.GetBoolean(4),
                    r.IsDBNull(6) ? "" : r.GetString(6),
                    r.IsDBNull(7) ? "" : r.GetString(7),
                    r.IsDBNull(5) ? null : r.GetString(5)));
            }
        }

        return new SchemaDto(schema, true,
            tables.Values.OrderBy(t => t.Name, StringComparer.OrdinalIgnoreCase)
                  .Select(t => new SchemaTableDto(t.Name, t.RowCount, t.Columns, t.Indexes))
                  .ToList());
    }

    // SSMS-style type rendering. NOTE max_length is in BYTES: n-types must be halved,
    // and -1 means (max).
    private static string FormatType(string type, short maxLen, byte precision, byte scale) => type switch
    {
        "varchar" or "char" or "varbinary" or "binary" =>
            maxLen == -1 ? $"{type}(max)" : $"{type}({maxLen})",
        "nvarchar" or "nchar" =>
            maxLen == -1 ? $"{type}(max)" : $"{type}({maxLen / 2})",
        "decimal" or "numeric" => $"{type}({precision},{scale})",
        "datetime2" or "time" or "datetimeoffset" => $"{type}({scale})",
        "float" or "real" => $"{type}({precision})",
        _ => type,
    };

    private sealed class SchemaTableRow(string name, long rowCount)
    {
        public string Name { get; } = name;
        public long RowCount { get; } = rowCount;
        public List<SchemaColumnDto> Columns { get; } = new();
        public List<SchemaIndexDto> Indexes { get; } = new();
    }
}
