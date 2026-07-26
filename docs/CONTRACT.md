# SQL Performance Playground — Shared Contract

This document is the **single source of truth** shared by every workstream (API, web SPA,
lesson authoring). Do not change a shape here without updating this file. All three
workstreams are built to match exactly what is written below.

---

## 1. Repository layout

```
sql-performance/
├── docker-compose.yml
├── .env.example
├── README.md
├── docs/
│   └── CONTRACT.md            (this file)
├── lessons/                   lesson content, one folder per lesson
│   ├── beginner/
│   │   └── <lesson-id>/
│   │       ├── manifest.json
│   │       ├── seed.sql
│   │       └── solution.sql
│   ├── intermediate/
│   ├── advanced/
│   └── expert/
├── api/                       ASP.NET Core Web API (C#)
│   └── SqlPerf.Api/
└── web/                       React SPA (Vite + TypeScript)
```

Lesson folders are mounted read-only into the API container at `/lessons`.

---

## 2. Lesson manifest schema (`manifest.json`)

```jsonc
{
  "id": "b-01-table-scan-vs-seek",   // globally unique, kebab-case; folder name must match
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

  // Database this lesson's SQL runs against. Created/reset from seed.sql.
  // Convention: "Lesson_<id-with-underscores>". The API derives it if omitted.
  "database": "Lesson_b_01_table_scan_vs_seek",

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

`seed.sql` — idempotent script that (re)creates the lesson database and its objects/data.
It MUST begin by dropping and recreating the database so reset is deterministic:

```sql
-- seed.sql skeleton
IF DB_ID('Lesson_b_01_table_scan_vs_seek') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_01_table_scan_vs_seek SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_01_table_scan_vs_seek;
END
GO
CREATE DATABASE Lesson_b_01_table_scan_vs_seek;
GO
USE Lesson_b_01_table_scan_vs_seek;
GO
-- tables, data, indexes (the deliberately "bad" starting state) ...
```

Seed scripts are split on `GO` batch separators by the API before execution.

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
Drops and re-seeds the lesson database from `seed.sql`.
```json
{ "status": "reset", "database": "Lesson_b_01_table_scan_vs_seek", "elapsedMs": 850 }
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
Clears all recorded lesson-completion progress (`AppMeta.dbo.LessonProgress`).
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

## 5. Conventions & limits

- Row cap per result set: **500** (`truncated: true` beyond that).
- Query timeout: **30s** (concurrency timeout: **15s** per session wait).
- The API captures the **actual** execution plan (`SET STATISTICS XML ON`), plus
  `SET STATISTICS IO ON` and `SET STATISTICS TIME ON`, and reads the messages.
- `resultUnchanged` baseline: the seed script may create a `__baseline` table/view or the
  API captures the starting query's result on first load; the lesson author decides via a
  `baselineQuery` field if the learner's query differs from the starting one. For the POC,
  `resultUnchanged` compares against the `startingQuery` result captured at reset time.
- Lesson databases are named `Lesson_<id>` with hyphens converted to underscores.
- The API user is `sa` (dev only) so it can create databases and read DMVs.
```
