# SQL Performance Playground — Shared Contract

This document is the shared reference for every workstream (API, web SPA, lesson and module
authoring). Do not change a shape here without updating this file.

> **On conflict, `api/SqlPerf.Api/Models/Contracts.cs` wins.** That file is compiled and
> tested; this one is prose and has drifted before. If the two disagree, the code is right
> and this document is a bug — fix it.

The app has **two curriculum tracks**, both built from the same machinery:

| Track | Key | What it teaches |
|---|---|---|
| SQL Performance | `perf` | Tuning real T-SQL: indexes, plan reading, concurrency, engine internals |
| Database Design | `design` | Modelling schemas on an ERD canvas, then building them for real |

A design module *is* a lesson with `kind: "design"`. Seeding, schema isolation, running SQL,
resetting and progress are all the same code; only the canvas and its grading are new.

---

## 1. Repository layout

```
sql-performance/
├── docker-compose.yml
├── .env.example
├── README.md
├── docs/
│   └── CONTRACT.md            (this file)
├── lessons/                   content, one folder per lesson or module
│   ├── beginner/              perf track
│   │   └── <lesson-id>/
│   │       ├── manifest.json
│   │       ├── seed.sql
│   │       └── solution.sql
│   ├── intermediate/
│   ├── advanced/
│   ├── expert/
│   └── design/                design track
│       ├── beginner/
│       │   └── <module-id>/   same three files
│       ├── intermediate/
│       ├── advanced/
│       └── expert/
├── api/                       ASP.NET Core Web API (C#)
│   └── SqlPerf.Api/
└── web/                       React SPA (Vite + TypeScript)
```

Lesson folders are mounted read-only into the API container at `/lessons`.

**Folder layout is convention, not configuration.** `LessonCatalog` discovers content with a
recursive glob for `manifest.json`; the `level` and `track` come from the manifest, not the
path. Adding content is still a no-code operation.

### Storage model

All lessons and modules share **one physical database** (`Sql:AppDatabase`, default
`SqlPerfDb`), isolated by a **SQL schema per lesson** plus a contained `EXECUTE AS` user
(`u_<schema>`) with `db_owner` and that schema as its `DEFAULT_SCHEMA`. The schema name is
always derived from the id (`-` → `_`); a manifest's `database` field is ignored.

This replaced an earlier one-database-per-lesson model, and the reason matters: Azure SQL's
free tier is one database per tenant, not a pool. **Never add a second database** — including
for progress or saved diagrams. Add schemas and tables inside the app database.

Two `dbo` tables live alongside the lesson schemas:

| Table | Holds |
|---|---|
| `dbo.LessonProgress` | Completion, best logical reads, best duration, first solved timestamp |
| `dbo.DesignCanvas` | Saved ERD diagrams (`ModuleId`, `ModelJson`, `SchemaVersion`, `UpdatedAtUtc`) |

---

## 2. Lesson manifest schema (`manifest.json`)

```jsonc
{
  "id": "b-01-table-scan-vs-seek",   // globally unique across BOTH tracks, kebab-case;
                                      // folder name must match
  "track": "perf",                    // OPTIONAL, default "perf". perf | design
  "kind": "query",                    // OPTIONAL, default "query". query | design
  "level": "beginner",               // beginner | intermediate | advanced | expert
  "order": 1,                         // sort order within the level
  "title": "Table Scan vs. Index Seek",
  "description": "One-sentence summary shown in the lesson navigator so the learner knows what the lesson is about before opening it.",
  "topics": ["indexing", "plan-reading"],   // free-form tags for filtering
  "estimatedMinutes": 10,

  // Markdown. Rendered in the lesson narrative panel.
  "narrative": "## The problem\nThe `Orders` table has 200k rows...",

  // The query shown in the editor when the lesson first loads (the "bad" query).
  "startingQuery": "SELECT * FROM Orders WHERE CustomerId = 42;",

  // IGNORED. A leftover from the one-database-per-lesson model. The SQL schema
  // is always derived from the id, and any value here is discarded.
  "database": "ignored",

  // OPTIONAL. Where the module's technical claims were verified. Required in
  // practice for new content — see "Content quality" below.
  "references": [
    { "title": "Primary and foreign key constraints", "url": "https://learn.microsoft.com/..." }
  ],

  // Progressive hints, revealed one at a time in the UI.
  "hints": [
    "Look at the operator in the plan — is it a scan or a seek?",
    "There is no index supporting the CustomerId predicate.",
    "Create a nonclustered index on Orders(CustomerId)."
  ],

  // Automated pass conditions. ALL must pass for the lesson to be solved.
  // See section 4 for the full rule vocabulary.
  "passConditions": [
    { "type": "noOperator", "operator": "Table Scan" },
    { "type": "maxLogicalReads", "table": "Orders", "value": 100 },
    { "type": "resultUnchanged" }
  ],

  // OPTIONAL. Present only for concurrency (blocking/deadlock) lessons.
  // When present, the UI shows the "Concurrency" run mode instead of a normal editor run.
  "interleaving": {
    "description": "Two sessions update rows in opposite order and deadlock.",
    "sessions": {
      "A": [
        { "sql": "BEGIN TRAN; UPDATE Accounts SET Balance -= 100 WHERE Id = 1;", "afterMs": 0 },
        { "sql": "UPDATE Accounts SET Balance += 100 WHERE Id = 2; COMMIT;", "afterMs": 300 }
      ],
      "B": [
        { "sql": "BEGIN TRAN; UPDATE Accounts SET Balance -= 50 WHERE Id = 2;", "afterMs": 0 },
        { "sql": "UPDATE Accounts SET Balance += 50 WHERE Id = 1; COMMIT;", "afterMs": 300 }
      ]
    },
    // What the learner must change to resolve it. Evaluated the same way as passConditions
    // but against the concurrency outcome (see section 4, concurrency rules).
    "resolveConditions": [
      { "type": "noDeadlock" }
    ],
    // The editor content for concurrency lessons is the fix the learner proposes:
    // e.g. reordered UPDATE statements or added lock hints. The learner edits the
    // session scripts shown in the UI. The starting scripts are `sessions` above.
    "solutionNote": "Access rows in a consistent order (Id 1 then Id 2) in both sessions."
  }
}
```

`solution.sql` — reference solution query (or corrected scripts for concurrency lessons).
Served only after the lesson is solved or on explicit "Show solution" request.

`seed.sql` — idempotent script that creates the lesson's objects and data. It does **not**
create a database, and it does **not** `USE` one. The API drops every object in the lesson's
schema, recreates the schema and its contained user, and then runs these batches while
impersonating that user, whose `DEFAULT_SCHEMA` is the lesson's schema. Unqualified names
therefore land in the right place automatically:

```sql
-- seed.sql skeleton
IF OBJECT_ID('Orders') IS NOT NULL DROP TABLE Orders;

CREATE TABLE Orders (
    OrderId    int NOT NULL IDENTITY(1,1) PRIMARY KEY,
    CustomerId int NOT NULL
);
GO

INSERT INTO Orders (CustomerId) VALUES (42);
GO
```

On Azure SQL, `CREATE SCHEMA` must be alone in its batch and `DB_ID(name)` resolves only the
currently-connected database — both are already handled by the API, but any new provisioning
SQL must follow the same discipline.

Seed scripts are split on `GO` batch separators by the API before execution.

---

## 2b. Design module manifest (`kind: "design"`)

A design module uses everything above, plus the fields below. All are optional and defaulted,
so adding them never breaks an existing manifest.

```jsonc
{
  "id": "d-b-05-one-to-many",
  "track": "design",
  "kind": "design",
  "level": "beginner",
  "order": 5,

  // The module's staged flow, shown as a rail alongside the narrative.
  "steps": [
    { "kind": "read",   "anchor": "scenario" },
    { "kind": "canvas", "prompt": "Add an Orders table and connect it to Customers." },
    { "kind": "sql",    "prompt": "Generate the DDL, read it, and run it." }
  ],

  // The canvas the module opens on, before the learner has saved anything.
  "startingModel": {
    "entities": [
      { "id": "e-customers", "name": "Customers", "x": 80, "y": 120,
        "attributes": [
          { "name": "CustomerId", "dataType": "int", "isPrimaryKey": true, "isIdentity": true },
          { "name": "Email", "dataType": "nvarchar(200)", "nullable": false }
        ] }
    ],
    "relationships": []
  },

  // OPTIONAL reference solution, in the same shape as startingModel.
  "targetModel": { "entities": [], "relationships": [] },

  // Graded against the schema the learner's DDL actually created.
  // See section 4b. A module may also carry passConditions; results concatenate.
  "designConditions": [
    { "type": "entityExists", "table": "Orders" },
    { "type": "foreignKey", "table": "Orders", "columns": ["CustomerId"],
      "references": "Customers", "cardinality": "manyToOne" }
  ]
}
```

**`ErdRelationship`** — `fromEntityId` is the **child** (the side that carries the foreign
key); `toEntityId` is the parent. `cardinality` is `manyToOne` | `oneToOne` | `manyToMany`;
`onDelete` is `NO ACTION` | `CASCADE` | `SET NULL`. A `manyToMany` relationship has no direct
DDL form and is emitted as a junction table.

`seed.sql` is still required. Keep design seeds **tiny** — tens of rows, not the perf track's
1.2 million. These modules teach structure, not volume, and 35 more schemas share one
free-tier database.

---

## 3. HTTP API

Base URL inside compose network: `http://api:8080`. Exposed on host: `http://localhost:5080`.
All responses are JSON. All bodies are UTF-8. CORS allows the web origin.

### `GET /api/health`
```json
{ "status": "ok", "sqlServer": "connected", "lessonsLoaded": 12 }
```

### `GET /api/levels`
Returns the curriculum grouped by level, with per-lesson progress merged in.
```json
[
  {
    "level": "beginner",
    "title": "Beginner",
    "lessons": [
      {
        "id": "b-01-table-scan-vs-seek",
        "order": 1,
        "title": "Table Scan vs. Index Seek",
        "topics": ["indexing", "plan-reading"],
        "estimatedMinutes": 10,
        "isConcurrency": false,
        "solved": true,
        "bestLogicalReads": 4,
        "bestDurationMs": 2
      }
    ]
  }
]
```

### `GET /api/lessons/{id}/schema`
Table/column/index/foreign-key metadata for the lesson's schema, read on a **separate
connection** from `/run` so metadata reads cannot pollute the `STATISTICS IO` counts that
`maxLogicalReads` grades on. Every query is scoped by `SCHEMA_ID`, so a lesson cannot
enumerate another lesson's objects. Returns `seeded: false` rather than 404 when the schema
does not exist yet.

```json
{
  "schema": "b_01_table_scan_vs_seek",
  "seeded": true,
  "tables": [
    {
      "name": "Orders", "rowCount": 200000, "isJunction": false,
      "columns": [
        { "name": "OrderId", "dataType": "int", "nullable": false,
          "isIdentity": true, "inPrimaryKey": true }
      ],
      "indexes": [
        { "name": "PK_Orders", "type": "CLUSTERED", "isUnique": true, "isPrimaryKey": true,
          "keyColumns": "OrderId ASC", "includedColumns": "", "filter": null }
      ],
      "foreignKeys": [
        { "name": "FK_Orders_Customers", "table": "Orders", "columns": "CustomerId",
          "referencedTable": "Customers", "referencedColumns": "CustomerId",
          "onDelete": "NO ACTION", "onUpdate": "NO ACTION", "isDisabled": false,
          "cardinality": "manyToOne" }
      ]
    }
  ]
}
```

`cardinality` is **derived, not declared**: a foreign key whose child columns are covered by
a unique index or primary key can match only one parent row, so it is `oneToOne`; otherwise
`manyToOne`. Many-to-many is not a property of a key, so it is detected per table —
`isJunction` is true when a table has exactly two foreign keys whose columns together form
its whole primary key.

### `GET /api/lessons/{id}`
Full lesson detail (does NOT include solution).
```json
{
  "id": "b-01-table-scan-vs-seek",
  "level": "beginner",
  "title": "Table Scan vs. Index Seek",
  "topics": ["indexing", "plan-reading"],
  "estimatedMinutes": 10,
  "narrative": "## The problem ...",     // markdown
  "startingQuery": "SELECT * FROM Orders WHERE CustomerId = 42;",
  "hints": ["...", "...", "..."],
  "isConcurrency": false,
  "interleaving": null,                   // or the interleaving object (without solutionNote)
  "progress": { "solved": true, "bestLogicalReads": 4, "bestDurationMs": 2 }
}
```

### `GET /api/lessons/{id}/solution`
```json
{ "solution": "CREATE INDEX IX_Orders_CustomerId ON Orders(CustomerId);\nSELECT ..." }
```

### `POST /api/lessons/{id}/run`
Executes the learner's SQL against the lesson database, captures stats + actual plan,
evaluates pass conditions.

Request:
```json
{ "sql": "CREATE INDEX ...; SELECT * FROM Orders WHERE CustomerId = 42;" }
```

Response (`RunResult`):
```json
{
  "success": true,                        // false if the SQL itself errored
  "error": null,                          // SQL error message when success=false

  "resultSets": [                         // capped rows per statement that returns rows
    {
      "columns": ["OrderId", "CustomerId", "Total"],
      "rows": [[1, 42, 99.5], [2, 42, 10.0]],
      "rowCount": 2,
      "truncated": false                  // true if more rows existed than the cap (500)
    }
  ],

  "stats": {
    "totalLogicalReads": 4,
    "totalPhysicalReads": 0,
    "cpuTimeMs": 0,
    "elapsedTimeMs": 2,
    "rowsAffected": 2,
    "perTable": [                         // parsed from STATISTICS IO
      { "table": "Orders", "logicalReads": 4, "physicalReads": 0, "scanCount": 1 }
    ]
  },

  "plan": {                               // parsed execution plan; null if unavailable
    "root": { /* PlanNode, see below */ },
    "warnings": [                         // plan-level warnings surfaced for teaching
      { "type": "MissingIndex", "impact": 92.7, "detail": "Orders(CustomerId)" }
    ],
    "missingIndexes": [
      { "impact": 92.7, "statement": "CREATE NONCLUSTERED INDEX ... ON Orders (CustomerId)" }
    ]
  },

  "messages": ["Table 'Orders'. Scan count 1, logical reads 4, ..."],   // raw SQL messages

  "evaluation": {
    "passed": true,
    "conditions": [
      { "type": "noOperator", "label": "No Table Scan", "passed": true, "detail": "..." },
      { "type": "maxLogicalReads", "label": "Logical reads on Orders < 100", "passed": true, "detail": "4" }
    ]
  },

  "progress": { "solved": true, "bestLogicalReads": 4, "bestDurationMs": 2, "newlySolved": true }
}
```

`PlanNode` (recursive):
```json
{
  "nodeId": 0,
  "physicalOp": "Index Seek",
  "logicalOp": "Index Seek",
  "estimateRows": 2.0,
  "actualRows": 2,
  "estimatedCostPercent": 12.5,           // relative to whole plan
  "object": "Orders.IX_Orders_CustomerId",
  "warnings": ["ImplicitConversion"],     // node-level warnings, may be empty
  "children": [ /* PlanNode... */ ]
}
```

### `POST /api/lessons/{id}/run-concurrency`
Only for concurrency lessons. Runs the (possibly learner-edited) two-session interleaving
server-side and reports the outcome.

Request:
```json
{
  "sessions": {
    "A": [ { "sql": "...", "afterMs": 0 }, ... ],
    "B": [ { "sql": "...", "afterMs": 0 }, ... ]
  }
}
```

Response (`ConcurrencyResult`):
```json
{
  "outcome": "deadlock",                  // completed | deadlock | blocked-timeout | error
  "deadlockVictim": "B",                  // "A" | "B" | null
  "timeline": [                           // ordered events for the sequence diagram
    { "tMs": 0,   "session": "A", "event": "begin",   "detail": "BEGIN TRAN" },
    { "tMs": 5,   "session": "A", "event": "acquired", "detail": "X lock on Accounts(1)" },
    { "tMs": 300, "session": "B", "event": "blocked",  "detail": "waiting for X lock on Accounts(1)" },
    { "tMs": 340, "session": "B", "event": "deadlock-victim", "detail": "chosen as victim" }
  ],
  "deadlockGraphXml": "<deadlock>...</deadlock>",   // null when no deadlock
  "evaluation": {                         // evaluates resolveConditions
    "passed": false,
    "conditions": [ { "type": "noDeadlock", "label": "No deadlock occurs", "passed": false, "detail": "..." } ]
  },
  "progress": { "solved": false, "newlySolved": false }
}
```

### `POST /api/lessons/{id}/reset`
Drops every object in the lesson's schema and re-seeds it from `seed.sql`. `database` in the
response is the SQL **schema** name, kept for backwards compatibility with the SPA.

Drop order matters and is handled here: foreign keys are cleared first (a referenced parent
table cannot be dropped while a child still points at it), then triggers, procedures, views,
functions and finally tables — so a `SCHEMABINDING` view or function cannot block its own
base table.

```json
{ "status": "reset", "database": "b_01_table_scan_vs_seek", "elapsedMs": 850 }
```

### `GET /api/progress`
```json
{
  "totalLessons": 80,
  "solvedLessons": 12,
  "byLevel": [
    { "level": "beginner", "total": 20, "solved": 12 }
  ]
}
```

### `GET /api/settings/info`
Environment status shown on the Settings page.
```json
{ "sqlServerHost": "sqlserver,1433", "lessonsLoaded": 80, "progress": { "totalLessons": 80, "solvedLessons": 0, "byLevel": [...] } }
```

### `POST /api/settings/reset-all-databases`
Re-runs every lesson's `seed.sql`, recreating all lesson databases from scratch.
```json
{ "lessonsReset": 80, "failed": 0, "elapsedMs": 41230, "failures": [] }
```

### `POST /api/settings/reset-progress`
Clears all recorded lesson-completion progress (`dbo.LessonProgress`, in the shared app
database — there is no separate `AppMeta` database).
```json
{ "rowsCleared": 80 }
```

### `POST /api/settings/recreate-sql-container`
Disaster recovery: deletes the `sqlperf-sqlserver` container/image (and its data volume
unless `keepData` is set), pulls a fresh SQL Server 2022 image, recreates the container via
`docker compose` against the **host** Docker daemon (reached through a socket bind-mounted
into the `api` container — see README "Settings & disaster recovery" for the security
implications), waits for it to report healthy, then reseeds every lesson database.
Request: `{ "keepData": false }`
```json
{
  "success": true,
  "elapsedMs": 96000,
  "steps": [
    { "step": "stop-and-remove-container", "success": true, "output": "sqlperf-sqlserver" },
    { "step": "pull-fresh-image", "success": true, "output": "..." },
    { "step": "recreate-container", "success": true, "output": "..." },
    { "step": "wait-for-healthy", "success": true, "output": "healthy" }
  ],
  "reseed": { "lessonsReset": 80, "failed": 0, "elapsedMs": 41230, "failures": [] }
}
```

### Track-aware curriculum routes

`GET /api/tracks` — both tracks with their counts:
```json
[ { "key": "perf", "title": "SQL Performance", "description": "...",
    "totalLessons": 80, "solvedLessons": 12 },
  { "key": "design", "title": "Database Design", "description": "...",
    "totalLessons": 1, "solvedLessons": 0 } ]
```

`GET /api/levels?track=design` — as `GET /api/levels`, scoped to one track. **Omitting
`track` resolves to `perf`**, because that route predates tracks and its existing callers
must keep working.

`GET /api/progress?track=perf` — as `GET /api/progress`, scoped to one track. Here, omitting
`track` means **every** track; that is what the Settings page wants.

### Design module routes

All require `kind: "design"`; anything else returns 404.

| Route | Does |
|---|---|
| `GET /api/modules/{id}` | Module detail: narrative, hints, steps, `startingModel`, progress |
| `GET /api/modules/{id}/model` | The saved diagram, falling back to `startingModel` on a first visit |
| `PUT /api/modules/{id}/model` | Save the diagram. Body `{ "model": ErdModel }` |
| `POST /api/modules/{id}/ddl` | Generate T-SQL from a model. Body `{ "model": ErdModel }` → `{ "ddl", "warnings" }` |
| `POST /api/modules/{id}/check` | Run and grade. Body `{ "model": ErdModel }` **or** `{ "sql": "..." }` |
| `POST /api/modules/{id}/reset` | Reseed the schema **and** restore the diagram to `startingModel` |
| `GET /api/modules/{id}/schema` | As `GET /api/lessons/{id}/schema` |

`POST /api/modules/{id}/check` returns:
```json
{ "success": true, "error": null, "ddl": "CREATE TABLE ...", "warnings": [],
  "schema": { /* SchemaDto */ },
  "evaluation": { "passed": true, "conditions": [ /* as passConditions */ ] },
  "progress": { "solved": true, "newlySolved": true } }
```

**`sql` wins over `model` when both are present.** That is deliberate: the canvas is an input
method for DDL, not the graded artefact, so a learner who writes the DDL by hand must be able
to reach exactly the same grading path.

**Identifier safety.** Every name in a model is validated against
`^[A-Za-z_][A-Za-z0-9_]{0,127}$` and data types against a fixed allowlist, then
bracket-quoted. Invalid names are **rejected, not escaped** — model content reaches `EXEC`,
so this is a security control and not a formatting nicety.

---

## 4. Pass-condition rule vocabulary

Each rule is an object with a `type` and type-specific fields. The evaluation engine
produces a human `label` and `passed` boolean per rule. `perTable`/plan data comes from
the same run.

Query rules (evaluated against a `RunResult`):

| type              | fields                          | passes when |
|-------------------|---------------------------------|-------------|
| `noOperator`      | `operator` (e.g. "Table Scan")  | no plan node has that physical operator |
| `requireOperator` | `operator`                      | at least one plan node has that operator |
| `indexUsed`       | `index` (name)                  | a plan node's `object` references that index |
| `maxLogicalReads` | `table` (optional), `value`     | total (or per-table) logical reads ≤ value |
| `maxDurationMs`   | `value`                         | elapsedTimeMs ≤ value |
| `maxEstimatedCost`| `value`                         | plan total estimated subtree cost ≤ value |
| `noWarning`       | `warning` (e.g. "MissingIndex") | plan has no warning of that type |
| `rowCountEquals`  | `value`                         | total rows returned equals value |
| `resultUnchanged` | (none)                          | result set matches the lesson's expected baseline (seeded) |

Concurrency rules (evaluated against a `ConcurrencyResult`):

| type          | fields | passes when |
|---------------|--------|-------------|
| `noDeadlock`  | (none) | outcome != "deadlock" |
| `bothCommit`  | (none) | outcome == "completed" |
| `maxBlockMs`  | `value`| no blocked event lasted longer than value |

---

## 4b. Design-condition rule vocabulary

Design modules are graded by `DesignEvaluator`, which reads the `SchemaDto` produced **after**
the learner's DDL has run. Like the query evaluator, it generates the human-readable label
itself — authors write machine-readable intent only.

| type               | fields                                            | passes when |
|--------------------|---------------------------------------------------|-------------|
| `entityExists`     | `table`                                           | a table of that name exists in the schema |
| `columnExists`     | `table`, `column`, `pattern` (optional type prefix) | the column exists, and its type starts with `pattern` if given |
| `primaryKey`       | `table`, `columns` (optional)                     | the table has a primary key; with `columns`, exactly those |
| `notNullable`      | `table`, `column`                                 | the column exists and is `NOT NULL` |
| `foreignKey`       | `table`, `references`, `columns` (optional), `cardinality` (optional) | a foreign key points at `references`, on those columns, with that derived cardinality |
| `indexOnFk`        | `table`, `column` or `columns`                    | an index **leads** with those columns (so a composite index counts) |
| `namingConvention` | `pattern` (`PascalCase`\|`camelCase`\|`snake_case`\|regex), `scope` (`tables`\|`columns`\|`all`) | every name in scope matches |

### Grading reads the database, not the canvas

This is the central design decision of the design track and should not be quietly reversed.
The learner's model is turned into DDL, executed in their isolated schema, and the resulting
schema is read back from the engine's catalog views and graded. Two consequences:

- A diagram that would not actually build cannot pass.
- Grading is implementation-agnostic: ignoring the canvas and hand-writing equivalent DDL
  passes identically.

### Normal forms are graded structurally

2NF, 3NF and BCNF are statements about **functional dependencies**, which live in the problem
domain and not in `sys.columns`. They cannot be verified from schema metadata. Normalization
modules therefore assert the *structural fingerprint* of the correct decomposition — this
table exists, this column is gone from that one, this key connects them — using
`entityExists`, `columnAbsent`, `primaryKey` and `foreignKey` together.

**Never write a module narrative that claims more than the grader checked.** Where a rule is
a proxy, the narrative must say so.

---

## 4c. Content quality

The app is a learning tool first; the interactive machinery is scaffolding. Every module:

1. **Is verified against primary sources before it is written** — Microsoft Learn for anything
   SQL Server-specific, Codd/Date/Fagin for normal forms, Kimball for dimensional modelling.
   Sources go in the manifest's `references` array so claims stay auditable.
2. **Only claims what the app can demonstrate.** If a plan or a statistic can't be shown,
   the claim is cut or explicitly flagged as context rather than asserted.
3. **Teaches trade-offs, not rules** — each module states when its own advice is wrong.
4. **Gets a second fact-check pass before shipping**, with corrections applied.

---

## 5. Conventions & limits

- Row cap per result set: **500** (`truncated: true` beyond that).
- Query timeout: **30s** (concurrency timeout: **15s** per session wait).
- The API captures the **actual** execution plan (`SET STATISTICS XML ON`), plus
  `SET STATISTICS IO ON` and `SET STATISTICS TIME ON`, and reads the messages.
- **The SET options run in their own batch, ahead of the learner's SQL, not concatenated
  in front of it.** They are connection-scoped and persist for everything that follows.
  This is what allows `CREATE TRIGGER`, `CREATE PROCEDURE`, `CREATE VIEW` and
  `CREATE FUNCTION`, each of which SQL Server requires to be the first statement in its
  batch.
- **Learner SQL is split on `GO`** and the batches run in order on the same connection, so
  a single run can create several objects. Result sets from every batch are returned; the
  **last** plan captured wins, which by convention is the graded statement's.
- `resultUnchanged` baseline: the seed script may create a `__baseline` table/view or the
  API captures the starting query's result on first load; the lesson author decides via a
  `baselineQuery` field if the learner's query differs from the starting one. For the POC,
  `resultUnchanged` compares against the `startingQuery` result captured at reset time.
- Lesson SQL **schemas** are named after the id with hyphens converted to underscores; the
  contained user is `u_<schema>`.
- Locally the API connects as `sa` (dev only) so it can create the app database and read DMVs.
```
