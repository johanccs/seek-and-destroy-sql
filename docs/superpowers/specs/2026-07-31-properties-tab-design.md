# Table Properties Tab — Design

**Date:** 2026-07-31
**Status:** Approved, ready for implementation planning

## Problem

The lessons teach indexing, but the editor gives no way to see what indexes and
columns actually exist. To find out whether `Orders` already has an index on
`CustomerId`, what its key order is, or whether a column is `varchar(20)` or
`nvarchar(20)` — which is the entire point of the implicit-conversion lessons —
you have to write your own catalog query and lose your working SQL.

## Goal

A **Properties** tab beside Messages showing, SSMS-style, the tables in the
current lesson: their columns with data types, their primary key, and their
indexes with key column order and included columns.

## Decisions

### Always available, listing every table in the lesson

Chosen over "only the tables the last query touched". The tab is most useful
*before* you run anything, while deciding which column to index. This has one
structural consequence, handled in the design below: `ResultsPanel` currently
returns early when there is no result, so no tab strip renders before the first
run.

### Refreshed after every run

Lesson solutions typically `CREATE INDEX`. Re-fetching after each run — graded or
scratch — means a new index appears immediately, with its key order and included
columns visible. That feedback loop is most of the value: you can confirm you
built the index you meant to build.

Rejected: manual refresh only. It would be stale by default immediately after the
action most likely to change it.

## Non-goals

- Editing anything. The tab is read-only; schema changes happen through SQL in
  the editor, as they do now.
- Object types other than tables — no views, procedures, functions or triggers.
  The curriculum is about tables and indexes.
- Statistics objects, partitions, or storage/fragmentation detail. If a lesson
  needs those it teaches them through DMV queries in the editor.

## Design

### 1. API

New endpoint: `GET /api/lessons/{id}/schema`.

The handler resolves the lesson, calls `SqlExecutor.EnsureSeededAsync` so the
schema exists, then reads catalog views.

**Critical constraint: this must use its own connection, separate from any
graded run.** `SqlExecutor.RunAsync` wraps user SQL in
`SET STATISTICS IO ON; SET STATISTICS TIME ON; SET STATISTICS XML ON;` and the
grader parses those results. Metadata reads sharing that connection or batch
would corrupt the read counts `maxLogicalReads` grades on. A separate call on its
own connection cannot interfere.

**Scoping.** Lessons are isolated by schema inside one database
(`lesson.Database` holds the schema name, accessed through the contained user
`u_<schema>`). Every query filters on the schema's `schema_id`, resolved once,
never on a name pattern — so a lesson can never enumerate another lesson's tables.

**Data returned per table:** name, row count, columns, indexes.

- **Row count** from `sys.dm_db_partition_stats` (index_id 0 or 1). This is a
  metadata read — it does not scan, which matters because some lessons hold 1.2
  million rows.
- **Columns** from `sys.columns` joined to `sys.types`, ordered by
  `column_id`: name, formatted type, nullability, identity flag, and whether the
  column participates in the primary key.
- **Indexes** from `sys.indexes` joined to `sys.index_columns` and
  `sys.columns`, excluding heaps (`type = 0`): name, `CLUSTERED` /
  `NONCLUSTERED` / `CLUSTERED COLUMNSTORE` / `NONCLUSTERED COLUMNSTORE`,
  is_unique, is_primary_key, key columns **in key order with ASC/DESC**,
  included columns, and `filter_definition`.

**Type formatting** follows SSMS conventions:

| Base type | Rendered |
|---|---|
| `varchar`, `char`, `varbinary`, `binary` | `varchar(50)`, `varchar(max)` when max_length is -1 |
| `nvarchar`, `nchar` | `nvarchar(50)` — note `max_length` is in **bytes**, so halve it for the displayed length; `nvarchar(max)` when -1 |
| `decimal`, `numeric` | `decimal(18,2)` |
| `datetime2`, `time`, `datetimeoffset` | `datetime2(7)` |
| everything else | bare type name, e.g. `int`, `bit`, `datetime` |

The `nvarchar` byte-vs-character detail is easy to get wrong and would display
every `nvarchar(20)` as `nvarchar(40)`.

**DTOs** (added to `Models/Contracts.cs`):

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

### 2. API client

`web/src/api.ts` gains:

```ts
schema: (id: string) =>
  fetch(`${BASE}/api/lessons/${id}/schema`).then(json<SchemaDto>),
```

with matching TypeScript types in `web/src/types.ts`.

### 3. Tab strip restructure

`ResultsPanel.tsx:13` currently reads:

```tsx
if (!result) return <div className="tab-body muted">Run a query to see results…</div>;
```

That early return must go, so the tab strip renders before the first run. The
placeholder moves into the bodies of the four run-dependent tabs; Properties
renders regardless. The pass banner, the error banner and the plan-warning dot
all already read from `result`, so each needs a null guard once the early return
is removed — `result?.plan`, and render the banners only when `result` exists.

### 4. The Properties tab

A fifth `Tab` union member, `"properties"`, added after `"messages"`.

For each table, in name order:

- A header: table name and row count (e.g. `Orders — 200,000 rows`).
- **Columns** grid: Name / Type / Null / Key. Primary-key columns marked with a
  key glyph in the Key column.
- **Indexes** grid: Name / Type / Unique / Key columns / Included / Filter.
  Key columns show order and direction, e.g. `CustomerId ASC, OrderDate DESC`.
  A table with no indexes says so explicitly rather than rendering an empty grid.

Reuses the existing `table.grid` styling so it matches the Results grid, inside
the existing `.tab-body` which already scrolls.

### 5. Loading and refresh

`LessonView` owns the schema state, since it already owns the run lifecycle:

- Fetch on lesson open (the existing `useEffect` keyed on `lesson.id`).
- Re-fetch at the end of both `run` and `runSelection`, after the result lands.
- Also re-fetch after `reset`, which drops any indexes the user created.

Failures are non-fatal: the tab shows a short error and the rest of the app is
unaffected. A metadata endpoint failing must never block running SQL.

## Testing

No test framework exists in this repo (no API test project, no vitest; `web`
scripts are only `dev`, `build`, `preview`). Verification is integration-level.

1. `GET /api/lessons/b-01-table-scan-vs-seek/schema` returns the `Orders` table
   with its columns and its clustered primary key.
2. Column types render correctly — in particular an `nvarchar` column shows its
   character length, not its byte length.
3. Open the lesson: the Properties tab is populated **before** any run.
4. The other four tabs still show their "run a query first" placeholder, and the
   tab strip is visible before the first run.
5. Run `CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON Orders(CustomerId) INCLUDE (Total);`
   then confirm the new index appears with the correct key and included columns
   without a manual refresh.
6. Reset the lesson and confirm the index disappears again.
7. A graded run's `maxLogicalReads` is unchanged by the presence of the tab —
   confirm b-01 still grades identically to before.
8. `dotnet build` and `npm --prefix web run build` both clean.

Author-testing through the real API records solves in the user's real progress;
clear `SqlPerfDb.dbo.LessonProgress` afterwards. Note a stale
`AppMeta.dbo.LessonProgress` also exists and deleting from it silently does
nothing.

## Risks

- **Read-count pollution** is the one that matters. Mitigated by a separate
  endpoint on its own connection; test 7 checks it.
- Catalog queries are cheap and read-only, so the blast radius is otherwise small.
- The `ResultsPanel` restructure touches a component every lesson renders. The
  null guards in section 3 are the specific risk; tests 3 and 4 cover it.
