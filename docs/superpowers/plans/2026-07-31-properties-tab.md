# Table Properties Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only SSMS-style **Properties** tab to the SQL IDE showing each table in the current lesson with its columns, primary key and indexes.

**Architecture:** A new `GET /api/lessons/{id}/schema` endpoint reads SQL Server catalog views on its own connection and returns tables/columns/indexes. `ResultsPanel` gains a fifth tab; `LessonView` owns the schema state and re-fetches it after every run and reset.

**Tech Stack:** ASP.NET Core minimal API (.NET 10), Microsoft.Data.SqlClient, React 18 + TypeScript, Vite, SQL Server 2022 in Docker.

Design spec: `docs/superpowers/specs/2026-07-31-properties-tab-design.md`

## Global Constraints

- **No test framework exists in this repo.** No API test project, no vitest/jest; `web` scripts are only `dev`, `build`, `preview`. Verification is integration-level: HTTP against the running API plus in-browser checks. Do not invent unit-test commands; do not add a test harness.
- **`npm --prefix web run build` runs `tsc -b && vite build`** — that single command is the frontend build+typecheck gate.
- **API base URL is `http://localhost:5080`** (health: `/api/health`). Not port 5000.
- **`sqlperf-web` serves a baked nginx build.** Frontend changes are invisible at `http://localhost:5173` until `docker compose up -d --build web`. For iteration use `npm --prefix web run dev`.
- **Metadata must never share a connection or batch with a graded run.** `SqlExecutor.RunAsync` prepends `SET STATISTICS IO ON; SET STATISTICS TIME ON; SET STATISTICS XML ON;` and the grader parses those counts. Corrupting them breaks `maxLogicalReads` grading across the curriculum.
- **Lessons are isolated by schema, not database.** `lesson.Database` holds the *schema* name inside `SqlPerfDb`. Scope every catalog query by resolved `schema_id`, never by name pattern.
- **The live progress table is `SqlPerfDb.dbo.LessonProgress`.** A stale `AppMeta.dbo.LessonProgress` also exists; deleting from it succeeds and silently clears nothing.
- **Use the PowerShell tool for `docker exec … sqlcmd`.** Git Bash mangles the `/opt/...` container path.
- Read-only feature: no DDL, no writes, no changes to grading behaviour.

---

### Task 1: Schema endpoint

**Files:**
- Modify: `api/SqlPerf.Api/Models/Contracts.cs` (add DTOs)
- Create: `api/SqlPerf.Api/Services/SchemaReader.cs`
- Modify: `api/SqlPerf.Api/Program.cs` (register service + endpoint)

**Interfaces:**
- Consumes: `SqlExecutor.EnsureSeededAsync(lesson)`, `LessonCatalog.Get(id)`, `Lesson.Database` (the schema name).
- Produces: `GET /api/lessons/{id}/schema` returning `SchemaDto(string Schema, List<SchemaTableDto> Tables)`.

- [ ] **Step 1: Add the DTOs**

Append to `api/SqlPerf.Api/Models/Contracts.cs`:

```csharp
public sealed record SchemaColumnDto(
    string Name, string DataType, bool Nullable, bool IsIdentity, bool InPrimaryKey);

public sealed record SchemaIndexDto(
    string Name, string Type, bool IsUnique, bool IsPrimaryKey,
    string KeyColumns, string IncludedColumns, string? Filter);

public sealed record SchemaTableDto(
    string Name, long RowCount,
    List<SchemaColumnDto> Columns, List<SchemaIndexDto> Indexes);

public sealed record SchemaDto(string Schema, List<SchemaTableDto> Tables);
```

- [ ] **Step 2: Create the reader service**

Create `api/SqlPerf.Api/Services/SchemaReader.cs`. Model the connection setup on the existing `SqlExecutor` — read the same `ConnectionStrings:Sql` and `Sql:AppDatabase` configuration and build the connection the same way, so the two stay consistent.

```csharp
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
        if (tables.Count == 0) return new SchemaDto(schema, new List<SchemaTableDto>());

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

        return new SchemaDto(schema,
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
```

- [ ] **Step 3: Register the service and the endpoint**

In `api/SqlPerf.Api/Program.cs`, register `SchemaReader` alongside the other services (find the existing `builder.Services.AddSingleton<SqlExecutor>()` line and add one beside it):

```csharp
builder.Services.AddSingleton<SchemaReader>();
```

Then add the endpoint next to the other `MapGet` lesson endpoints:

```csharp
// ---- Table/column/index metadata for the lesson's schema ----
// Separate endpoint and separate connection from /run on purpose: see SchemaReader.
app.MapGet("/api/lessons/{id}/schema", async (string id, LessonCatalog cat,
    SqlExecutor exec, SchemaReader schema) =>
{
    var l = cat.Get(id);
    if (l is null) return Results.NotFound();
    await exec.EnsureSeededAsync(l);
    return Results.Json(await schema.ReadAsync(l.Database));
});
```

- [ ] **Step 4: Build**

```bash
cd X:/Playground/sql-performance && dotnet build api/SqlPerf.Api/SqlPerf.Api.csproj -c Release
```

Expected: succeeds. A pre-existing `CA2024` warning on `Services/TutorService.cs:143` is unrelated — ignore it.

- [ ] **Step 5: Deploy and verify the endpoint**

```bash
cd X:/Playground/sql-performance && docker compose up -d --build api
curl -s -m 10 http://localhost:5080/api/health
curl -s -m 120 http://localhost:5080/api/lessons/b-01-table-scan-vs-seek/schema | jq '{schema, tables: [.tables[] | {name, rowCount, cols: (.columns|length), idx: [.indexes[].name]}]}'
```

Expected: an `Orders` table with a non-zero `rowCount`, several columns, and at least its primary-key index listed.

- [ ] **Step 6: Verify type formatting, especially nvarchar**

```bash
curl -s -m 60 http://localhost:5080/api/lessons/i-08-unicode-implicit-conversion/schema | jq '[.tables[] | {name, columns: [.columns[] | {name, dataType}]}]'
```

Expected: types render SSMS-style. Any `nvarchar(20)` column must show **`nvarchar(20)`**, not `nvarchar(40)` — `max_length` is in bytes and the formatter halves it for n-types. If you see doubled lengths, the halving is wrong.

- [ ] **Step 7: Verify grading is unaffected**

The whole risk of this feature is polluting the read counts the grader uses. Confirm b-01 still grades identically.

```bash
curl -s -X POST -m 120 http://localhost:5080/api/lessons/b-01-table-scan-vs-seek/reset
curl -s -m 120 -X POST http://localhost:5080/api/lessons/b-01-table-scan-vs-seek/run \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT * FROM Orders WHERE CustomerId = 42;"}' | jq '{passed: .evaluation.passed, reads: .stats.totalLogicalReads}'
```

Expected: `passed: false` (no index yet after the reset) with a read count in the ~1000 range — the same behaviour as before this change. The point is that fetching schema metadata does not alter it.

Then clear the progress row, **using the PowerShell tool**:

```powershell
docker exec -i sqlperf-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Sql_Perf_Pass123!' -C -b -Q "DELETE FROM SqlPerfDb.dbo.LessonProgress WHERE LessonId='b-01-table-scan-vs-seek'"
```

- [ ] **Step 8: Commit**

```bash
cd X:/Playground/sql-performance
git add api/SqlPerf.Api/Models/Contracts.cs api/SqlPerf.Api/Services/SchemaReader.cs api/SqlPerf.Api/Program.cs
git commit -m "Add schema metadata endpoint for the Properties tab

GET /api/lessons/{id}/schema returns each table in the lesson's schema with
its columns, primary key and indexes (key column order, included columns,
filter). Row counts come from sys.dm_db_partition_stats so nothing scans.

Reads run on their own connection, never shared with /run: SqlExecutor wraps
user SQL in SET STATISTICS IO and the grader parses those counts, so sharing
would corrupt what maxLogicalReads grades on. Every query is scoped by
SCHEMA_ID so a lesson cannot enumerate another lesson's tables."
```

---

### Task 2: Properties tab in the UI

**Files:**
- Modify: `web/src/types.ts` (schema types)
- Modify: `web/src/api.ts` (client method)
- Modify: `web/src/components/ResultsPanel.tsx` (remove early return, add tab)
- Modify: `web/src/components/LessonView.tsx` (own + refresh schema state)
- Modify: `web/src/styles.css` (Properties styling)

**Interfaces:**
- Consumes: `GET /api/lessons/{id}/schema` from Task 1, shape `SchemaDto`.
- Produces: `ResultsPanel` accepts `schema: SchemaInfo | null` and `schemaError: string | null`.

- [ ] **Step 1: Add the types**

Append to `web/src/types.ts`:

```ts
export type SchemaColumn = {
  name: string; dataType: string; nullable: boolean; isIdentity: boolean; inPrimaryKey: boolean;
};
export type SchemaIndex = {
  name: string; type: string; isUnique: boolean; isPrimaryKey: boolean;
  keyColumns: string; includedColumns: string; filter: string | null;
};
export type SchemaTable = {
  name: string; rowCount: number; columns: SchemaColumn[]; indexes: SchemaIndex[];
};
export type SchemaInfo = { schema: string; tables: SchemaTable[] };
```

- [ ] **Step 2: Add the client method**

In `web/src/api.ts`, add alongside the other methods (and add `SchemaInfo` to the existing `import type` from `./types`):

```ts
  schema: (id: string) =>
    fetch(`${BASE}/api/lessons/${id}/schema`).then(json<SchemaInfo>),
```

- [ ] **Step 3: Own the schema state in LessonView**

In `web/src/components/LessonView.tsx`, add state beside the existing `result` state:

```ts
  const [schema, setSchema] = useState<SchemaInfo | null>(null);
  const [schemaError, setSchemaError] = useState<string | null>(null);
```

Add a loader, defined before the effects that use it:

```ts
  // Metadata is advisory: a failure here must never block running SQL.
  const loadSchema = async () => {
    try {
      setSchema(await api.schema(lesson.id));
      setSchemaError(null);
    } catch (e) {
      setSchemaError(String(e));
    }
  };
```

Import `SchemaInfo` in the existing `import type` line from `../types`.

- [ ] **Step 4: Load on open and refresh after every run and reset**

In the existing `useEffect` keyed on `lesson.id` (the one calling `setSql(lesson.startingQuery)`), add `setSchema(null); setSchemaError(null); loadSchema();` so switching lessons clears stale data and reloads.

Then call `loadSchema()` at the end of the `try` block in **each** of `run`, `runSelection` and `reset`, after the result state is set. All three can change schema: runs may create or drop indexes, and reset restores the original schema.

- [ ] **Step 5: Pass it to ResultsPanel**

```tsx
<ResultsPanel result={result} prevStats={prevStats} scratch={scratch} onResizeStart={onResultsResizeStart} schema={schema} schemaError={schemaError} />
```

- [ ] **Step 6: Restructure ResultsPanel so tabs always render**

In `web/src/components/ResultsPanel.tsx`:

Extend the tab union and the props:

```tsx
type Tab = "results" | "stats" | "plan" | "messages" | "properties";
```

```tsx
export function ResultsPanel({ result, prevStats, scratch = false, onResizeStart, schema, schemaError }: { result: RunResult | null; prevStats: RunStats | null; scratch?: boolean; onResizeStart?: (e: React.MouseEvent) => void; schema?: SchemaInfo | null; schemaError?: string | null }) {
```

**Delete this line entirely** (currently line 13) — it is what stops the tab strip rendering before a run:

```tsx
  if (!result) return <div className="tab-body muted">Run a query to see results, statistics and the execution plan.</div>;
```

Removing it means everything below must tolerate a null `result`. Make these four changes:

```tsx
  const planWarnCount = (result?.plan?.warnings.length ?? 0) + (result?.plan?.missingIndexes.length ?? 0);
```

Guard the two banners so they only render with a result:

```tsx
        {result && <PassBanner evaluation={result.evaluation} newlySolved={result.progress?.newlySolved} />}
        {result?.error && <div className="banner fail"><div className="err">{result.error}</div></div>}
```

And give the four run-dependent tab bodies the placeholder when there is no result. Wrap their existing rendering so that, when `result` is null and the active tab is one of `results`/`stats`/`plan`/`messages`, the body is:

```tsx
        <div className="muted">Run a query to see results, statistics and the execution plan.</div>
```

Add the Properties tab button after the Messages tab button:

```tsx
          <div className={`tab ${tab === "properties" ? "active" : ""}`} onClick={() => setTab("properties")}>
            Properties
          </div>
```

- [ ] **Step 7: Render the Properties body**

Add alongside the other tab bodies in `ResultsPanel`:

```tsx
        {tab === "properties" && (
          schemaError ? <div className="err">Could not load table properties: {schemaError}</div>
          : !schema ? <div className="muted">Loading table properties…</div>
          : schema.tables.length === 0 ? <div className="muted">This lesson has no tables.</div>
          : (
            <div className="props">
              {schema.tables.map((t) => (
                <div className="props-table" key={t.name}>
                  <h4>{t.name} <span className="muted">— {t.rowCount.toLocaleString()} rows</span></h4>

                  <div className="props-sub">Columns</div>
                  <table className="grid">
                    <thead><tr><th>Name</th><th>Type</th><th>Null</th><th>Key</th></tr></thead>
                    <tbody>
                      {t.columns.map((c) => (
                        <tr key={c.name}>
                          <td>{c.name}</td>
                          <td>{c.dataType}{c.isIdentity && <span className="muted"> identity</span>}</td>
                          <td>{c.nullable ? "NULL" : "NOT NULL"}</td>
                          <td>{c.inPrimaryKey ? <span title="Primary key">🔑</span> : ""}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>

                  <div className="props-sub">Indexes</div>
                  {t.indexes.length === 0 ? (
                    <div className="muted props-none">No indexes on this table.</div>
                  ) : (
                    <table className="grid">
                      <thead><tr><th>Name</th><th>Type</th><th>Unique</th><th>Key columns</th><th>Included</th><th>Filter</th></tr></thead>
                      <tbody>
                        {t.indexes.map((i) => (
                          <tr key={i.name}>
                            <td>{i.isPrimaryKey && <span title="Primary key">🔑 </span>}{i.name}</td>
                            <td>{i.type}</td>
                            <td>{i.isUnique ? "Yes" : "No"}</td>
                            <td>{i.keyColumns}</td>
                            <td>{i.includedColumns || <span className="muted">—</span>}</td>
                            <td>{i.filter || <span className="muted">—</span>}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              ))}
            </div>
          )
        )}
```

- [ ] **Step 8: Style it**

Append to `web/src/styles.css`:

```css
/* Properties tab */
.props-table { margin-bottom: 22px; }
.props-table h4 { margin: 0 0 8px; font-size: 14px; }
.props-sub { font-size: 11px; text-transform: uppercase; letter-spacing: .8px; color: var(--text-dim); margin: 10px 0 4px; }
.props-none { font-size: 13px; padding: 4px 0; }
```

- [ ] **Step 9: Build**

```bash
cd X:/Playground/sql-performance && npm --prefix web run build
```

Expected: succeeds with no errors (`tsc -b` typechecks as part of it).

- [ ] **Step 10: Verify in the browser**

Start the dev server in the background (`npm --prefix web run dev`, Bash tool `run_in_background: true`) and drive it with the `agent-browser` CLI: `agent-browser set viewport 1500 950`, `open <url>`, `find text "..." click`, `wait --load networkidle`, `eval "<js>"`, `screenshot f.png`, `close --all` when done.

Check all of these:

1. Open **Table Scan vs. Index Seek**. The tab strip is visible **before any run**, and **Properties** is populated — this is the whole point of the restructure.
2. The other four tabs show "Run a query to see results…" and do not crash with no result.
3. `Orders` lists its columns with types, and its primary-key column is marked.
4. Run the graded query once. The other tabs fill in; Properties still works.
5. Run `CREATE NONCLUSTERED INDEX IX_Props_Test ON Orders(CustomerId) INCLUDE (Total);` and confirm `IX_Props_Test` appears in Properties **without a manual refresh**, showing key column `CustomerId ASC` and included `Total`.
6. Click **Reset Lesson**, then confirm `IX_Props_Test` is gone from Properties.
7. Confirm no horizontal page overflow with the Properties tab open on a narrow editor column — this project has a history of layout-overflow bugs, and the Indexes grid is six columns wide:
   `agent-browser eval "(()=>{const d=document.documentElement;return JSON.stringify({overflow:d.scrollWidth>innerWidth});})()"`

Kill the dev server when finished.

- [ ] **Step 11: Clear test progress**

Step 10 ran graded queries. **Using the PowerShell tool:**

```powershell
docker exec -i sqlperf-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Sql_Perf_Pass123!' -C -b -Q "DELETE FROM SqlPerfDb.dbo.LessonProgress WHERE LessonId='b-01-table-scan-vs-seek'"
```

- [ ] **Step 12: Commit**

```bash
cd X:/Playground/sql-performance
git add web/src/types.ts web/src/api.ts web/src/components/ResultsPanel.tsx web/src/components/LessonView.tsx web/src/styles.css
git commit -m "Add the Properties tab to the SQL IDE

A fifth tab beside Messages listing every table in the lesson with its
columns (SSMS-style types, nullability, identity, primary key) and its
indexes (type, uniqueness, key column order, included columns, filter).

ResultsPanel previously returned early when there was no result, so no tabs
rendered before the first run. That early return is gone and the placeholder
moved into the run-dependent tab bodies, so Properties is usable immediately —
which is when you are deciding what to index.

Schema reloads after every run and after reset, so an index you just created
appears straight away with its key order and included columns."
```

---

### Task 3: Regression check

**Files:** none — verification only.

- [ ] **Step 1: Rebuild the containers**

```bash
cd X:/Playground/sql-performance && docker compose up -d --build web && curl -s -m 10 http://localhost:5080/api/health
```

Expected: `lessonsLoaded: 80`.

- [ ] **Step 2: Confirm grading is untouched end to end**

Reset b-01, then in the browser at `http://localhost:5173` click **Show Solution** and press `Ctrl+Enter`. Confirm the pass banner appears and the sidebar tick turns green — the Properties feature must not have changed grading in any way.

- [ ] **Step 3: Confirm a concurrency lesson still works**

Search the sidebar for "blocking", open **Blocking: A Reader Stuck Behind an Uncommitted Writer**, and confirm its two session editors render and **Run Interleaving** still works. Concurrency lessons use `ConcurrencyView` rather than `ResultsPanel`, so this checks the restructure did not leak.

- [ ] **Step 4: Leave progress clean**

**Using the PowerShell tool:**

```powershell
docker exec -i sqlperf-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Sql_Perf_Pass123!' -C -b -Q "DELETE FROM SqlPerfDb.dbo.LessonProgress"
```

Then confirm `curl -s http://localhost:5080/api/progress | jq '{solvedLessons,totalLessons}'` shows `solvedLessons: 0`.

- [ ] **Step 5: Report**

Summarise what changed, the verification evidence, and that the branch is `feat/properties-tab` awaiting a merge decision. Do **not** merge or push without being asked — `ci.yml` auto-deploys to Azure on any push to `main`.
