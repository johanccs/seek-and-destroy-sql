# Beginner Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author the three remaining Beginner modules of the Database Design Hub (1, 2 and 10), taking the level from 7 of 10 to complete.

**Architecture:** Content only. Each module is a directory under `lessons/design/beginner/` holding `manifest.json`, `seed.sql` and `solution.sql`, plus an `id` added to the matching entry in `web/src/design/roadmap.ts`. All three reuse the existing `read → canvas → sql` step shape and the eleven rules already in `DesignEvaluator`. No API, evaluator or frontend code changes.

**Tech Stack:** SQL Server 2022 (Docker), .NET 8 minimal API, React + TypeScript SPA, Docker Compose.

## Global Constraints

- **Grading reads the real database, never the canvas.** Every `designConditions` entry must be a fact `SchemaReader` can read from engine metadata.
- **Only these eleven rule types exist.** Using any other string silently produces `"Unknown rule"` and a failed condition: `entityExists`, `columnExists`, `primaryKey`, `notNullable`, `hasDefault`, `checkConstraintExists`, `surrogateKey`, `naturalKeyUnique`, `foreignKey`, `indexOnFk`, `namingConvention`.
- **Never claim the grader checked something it did not.** The "How this is graded" section of each narrative must describe only the conditions actually listed.
- **Every SQL Server-specific claim is verified against Microsoft Learn before writing** and cited in the manifest's `references` array with a real URL. Use the `microsoft-docs` MCP tools. This is a hard requirement, not a nicety.
- **Teach trade-offs, never rules.** Each module states when its own advice is wrong.
- **Content is plain data with no csproj content items.** Do not add any; the CI deploy has an explicit copy step that handles it.
- Module ids are `d-b-01-what-a-data-model-is`, `d-b-02-tables-rows-columns-schemas`, `d-b-10-capstone-order-entry`. These strings appear in the directory name, the manifest `id`, and `roadmap.ts`. They must match exactly.
- All manifests set `"track": "design"`, `"kind": "design"`, `"level": "beginner"`, `"azureUnsupported": false`, and `"passConditions": []`.
- Work happens on branch `feat/beginner-completion`. Do not commit to `main` — merging to `main` auto-deploys to Azure.

## Environment setup (do this once, before Task 1)

The local stack is the test harness. Bring it up and confirm it answers:

```bash
docker compose up -d
curl -s http://localhost:5080/api/health
```

Expected: JSON including `"sqlServer"`. If it reports `disconnected`, wait ~15s and retry — the container is still starting. Probe two or three times before concluding anything is broken.

`docker-compose.yml:46` bind-mounts `./lessons:/lessons:ro`, so new module files are visible to the API without an image rebuild. `LessonCatalog` scans at startup, so **after adding or renaming a module directory you must run `docker compose restart api`** for it to appear.

The verification loop used throughout this plan:

```bash
curl -s -X POST http://localhost:5080/api/modules/<id>/check \
  -H 'Content-Type: application/json' \
  -d "$(jq -Rn --rawfile sql lessons/design/beginner/<dir>/solution.sql '{sql: $sql}')"
```

This posts the module's own solution as raw SQL — `CheckRequest(ErdModel? Model, string? Sql)` accepts either — runs it in the module's isolated schema, reads the schema back and grades it. A module is correct when `.evaluation.passed` is `true`.

---

### Task 1: Module 2 — tables, rows, columns and schemas

Delivered first because it is the most self-contained: one small table, and the teaching happens in the SQL step.

**Files:**
- Create: `lessons/design/beginner/d-b-02-tables-rows-columns-schemas/seed.sql`
- Create: `lessons/design/beginner/d-b-02-tables-rows-columns-schemas/manifest.json`
- Create: `lessons/design/beginner/d-b-02-tables-rows-columns-schemas/solution.sql`
- Modify: `web/src/design/roadmap.ts:19` (add `id` to the `n: 2` entry)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: module id `d-b-02-tables-rows-columns-schemas`. Establishes the vocabulary (table, row, column, schema, catalog) that modules 1 and 10 assume.

- [ ] **Step 1: Verify the schema claims against Microsoft Learn**

Before writing any narrative, confirm each claim with the `microsoft_docs_search` MCP tool and keep the URLs. The four claims to verify:

1. A schema is a named container/namespace for objects.
2. One-part name resolution: default schema first, then `dbo`, then error.
3. Schema permissions are inherited by objects added to the schema later.
4. Four-part naming is `Server.Database.DatabaseSchema.DatabaseObject`.

Expected sources (confirm they still say this, do not assume):
- `https://learn.microsoft.com/sql/relational-databases/security/authentication-access/ownership-and-user-schema-separation`
- `https://learn.microsoft.com/sql/relational-databases/system-catalog-views/schemas-catalog-views-sys-schemas`

- [ ] **Step 2: Confirm the DEFAULT_SCHEMA precondition still holds**

The module's headline demo depends on it. Run:

```bash
grep -n "DEFAULT_SCHEMA" api/SqlPerf.Api/Services/SqlExecutor.cs
```

Expected: a line creating the user `WITH DEFAULT_SCHEMA = [{schema}]` (currently `SqlExecutor.cs:241`). If this is gone, stop and rewrite the module around explicit two-part names instead of `SCHEMA_NAME()`.

- [ ] **Step 3: Write the seed**

The seed exists only to give the SQL step a second table to contrast with, so the catalog queries return more than one row.

```sql
-- Module 2 needs a table the learner did NOT create, so the catalog views have
-- something to show besides their own work.
IF OBJECT_ID('SignupSource') IS NOT NULL DROP TABLE SignupSource;

CREATE TABLE SignupSource (
    SignupSourceId int          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Name           nvarchar(40) NOT NULL,
    IsPaid         bit          NOT NULL
);
GO

INSERT INTO SignupSource (Name, IsPaid) VALUES
    ('Organic search', 0),
    ('Referral',       0),
    ('Paid social',    1);
GO
```

- [ ] **Step 4: Write the manifest**

Create `manifest.json` with the fields below. Write the `narrative` as a single JSON string with `\n` escapes, matching the house style of `d-b-09-constraints-as-documentation/manifest.json` — sections `## What This Lesson Is About`, `## Scenario`, `## Your task`, `## What to look for`, `## The concept`, `## How this is graded`.

```json
{
  "id": "d-b-02-tables-rows-columns-schemas",
  "track": "design",
  "kind": "design",
  "level": "beginner",
  "order": 2,
  "title": "Tables, Rows, Columns and Schemas",
  "description": "A table is not a spreadsheet — it is a row in sys.tables, and its columns are rows in sys.columns. Why it matters: once you can see that the database describes itself, schema qualification stops being ceremony and becomes the thing that decides which table your query actually hit.",
  "topics": ["tables", "schemas", "catalog views", "name resolution"],
  "estimatedMinutes": 20,
  "steps": [
    { "kind": "read", "anchor": "scenario" },
    { "kind": "canvas", "prompt": "Model a small Customers table: an identifier, a full name, and an email that is required." },
    { "kind": "sql", "prompt": "Run the DDL, then query the catalog views to see what the engine stored — and find out which schema you have been working in all along." }
  ],
  "hints": [
    "Keep the table small on purpose. Building it is not the lesson; looking at what the engine did with it is.",
    "SELECT SCHEMA_NAME() tells you your default schema. It is not dbo — this module has its own, and so does every other module in the app.",
    "Try SELECT * FROM SignupSource, then the same query with the schema name in front of it. Both work here. Now think about what happens when a table with that name also exists in dbo."
  ],
  "startingModel": {
    "entities": [
      {
        "id": "e-customers",
        "name": "Customers",
        "x": 140,
        "y": 110,
        "attributes": [
          { "name": "CustomerId", "dataType": "int", "isPrimaryKey": true, "isIdentity": true, "nullable": false }
        ]
      }
    ],
    "relationships": []
  },
  "designConditions": [
    { "type": "entityExists", "table": "Customers" },
    { "type": "primaryKey", "table": "Customers" },
    { "type": "columnExists", "table": "Customers", "column": "Email" },
    { "type": "notNullable", "table": "Customers", "column": "Email" }
  ],
  "references": [],
  "startingQuery": "SELECT SCHEMA_NAME() AS my_default_schema;",
  "passConditions": [],
  "azureUnsupported": false
}
```

Fill `references` with the URLs confirmed in Step 1, each as `{ "title": "...", "url": "..." }` where the title states the specific claim being cited (follow the style in `d-b-03-data-types/manifest.json:44-57`).

The narrative must include these four SQL snippets in the `## Scenario` or `## What to look for` sections:

```sql
SELECT SCHEMA_NAME() AS my_default_schema;
SELECT name, schema_id FROM sys.schemas;
SELECT t.name, s.name AS schema_name
  FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id;
SELECT name, system_type_id, max_length, is_nullable
  FROM sys.columns WHERE object_id = OBJECT_ID('Customers');
```

The narrative must make three points, and must state the trade-off in the last one:
1. A table is itself a row in `sys.tables` — the catalog is a database describing a database, which is also why the grader can read the learner's work back.
2. Columns are data. `sys.columns` returns the shape of the table as rows.
3. A schema is not a folder, it is a standing grant: permissions set on it are inherited by objects added later. **The trade-off to state:** schemas are free to create and cost nothing at runtime, but a schema per team sounds tidier than it is — cross-schema joins need qualification everywhere, and a default schema that differs per user turns an unqualified name into a question rather than an answer.

The `## How this is graded` section must say only that the check confirms the table exists with a primary key and a required `Email` column. It must **not** claim anything about schemas is graded, because nothing about schemas is.

- [ ] **Step 5: Write the solution**

```sql
-- Small on purpose. The lesson is what the engine did with it, not the table.
CREATE TABLE Customers (
    CustomerId int           NOT NULL IDENTITY(1,1),
    FullName   nvarchar(120) NOT NULL,
    Email      nvarchar(256) NOT NULL,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerId)
);

-- The table above is now itself a row in sys.tables:
--   SELECT t.name, s.name AS schema_name
--     FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id;
-- and its columns are rows in sys.columns:
--   SELECT name, system_type_id, max_length, is_nullable
--     FROM sys.columns WHERE object_id = OBJECT_ID('Customers');
```

- [ ] **Step 6: Register the module in the roadmap**

In `web/src/design/roadmap.ts`, the `n: 2` entry currently ends `"What the engine actually stores, and what a schema is for." }`. Add the id:

```ts
      { n: 2, title: "Tables, rows, columns and schemas", blurb: "What the engine actually stores, and what a schema is for.", id: "d-b-02-tables-rows-columns-schemas" },
```

- [ ] **Step 7: Restart the API so the catalog picks up the new module**

```bash
docker compose restart api
sleep 10
curl -s http://localhost:5080/api/modules/d-b-02-tables-rows-columns-schemas | head -c 200
```

Expected: JSON for the module, not a 404. A 404 means the directory name and manifest `id` do not match.

- [ ] **Step 8: Verify the check FAILS on the starting model**

This proves the conditions are actually asserting something. Post the starting model's DDL — a `Customers` table with only `CustomerId`:

```bash
curl -s -X POST http://localhost:5080/api/modules/d-b-02-tables-rows-columns-schemas/check \
  -H 'Content-Type: application/json' \
  -d '{"sql":"CREATE TABLE Customers (CustomerId int NOT NULL IDENTITY(1,1), CONSTRAINT PK_Customers PRIMARY KEY (CustomerId));"}' \
  | jq '.evaluation.passed, [.evaluation.conditions[] | {label, passed}]'
```

Expected: `false`, with `entityExists` and `primaryKey` passing and both `Email` conditions failing. If everything passes, the conditions are not testing what they claim — fix the manifest before continuing.

- [ ] **Step 9: Verify the check PASSES on the solution**

```bash
curl -s -X POST http://localhost:5080/api/modules/d-b-02-tables-rows-columns-schemas/check \
  -H 'Content-Type: application/json' \
  -d "$(jq -Rn --rawfile sql lessons/design/beginner/d-b-02-tables-rows-columns-schemas/solution.sql '{sql: $sql}')" \
  | jq '.evaluation.passed, [.evaluation.conditions[] | {label, passed}]'
```

Expected: `true`, all four conditions passing.

- [ ] **Step 10: Verify Check twice in a row still works**

Iterating on a model is exactly what a learner does, and the reset-before-DDL path is the thing that breaks. Run the Step 9 command again, unchanged.

Expected: `true` again, not a "there is already an object named 'Customers'" error.

- [ ] **Step 11: Verify the SQL step's queries actually run**

The narrative promises four queries. Confirm the catalog ones work under the module's contained user, and that `SCHEMA_NAME()` returns the module schema rather than `dbo`:

```bash
curl -s -X POST http://localhost:5080/api/modules/d-b-02-tables-rows-columns-schemas/check \
  -H 'Content-Type: application/json' \
  -d '{"sql":"SELECT SCHEMA_NAME() AS my_default_schema;"}' | jq '.error'
```

Then run the same module's SQL step in the browser at `http://localhost:5173` and confirm `SCHEMA_NAME()` returns something like `d_b_02_tables_rows_columns_schemas`, **not** `dbo`. If it returns `dbo`, the headline claim of the module is false — stop and rewrite that section.

- [ ] **Step 12: Commit**

```bash
git add lessons/design/beginner/d-b-02-tables-rows-columns-schemas web/src/design/roadmap.ts
git commit -m "Add the tables, rows, columns and schemas module

Module 2 uses the learner's own sandbox as its specimen: every module
gets its own schema and contained user, so SCHEMA_NAME() and the catalog
views demonstrate on real objects what the narrative claims.

The one-part name fallback (default schema, then dbo, then error) and
schema permission inheritance are cited to Microsoft Learn.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Module 1 — what a data model is

**Files:**
- Create: `lessons/design/beginner/d-b-01-what-a-data-model-is/seed.sql`
- Create: `lessons/design/beginner/d-b-01-what-a-data-model-is/manifest.json`
- Create: `lessons/design/beginner/d-b-01-what-a-data-model-is/solution.sql`
- Modify: `web/src/design/roadmap.ts:18` (add `id` to the `n: 1` entry)

**Interfaces:**
- Consumes: nothing. This is the first module a learner meets, so it may assume no prior module.
- Produces: module id `d-b-01-what-a-data-model-is`. Introduces `Customers` and `Orders` as the running example that module 10's capstone reuses.

- [ ] **Step 1: Write the seed**

One flat table with the customer's details repeated on every order. Deliberately not framed as normalization — that is module 11.

```sql
-- One flat table holding two different kinds of thing. The customer's details
-- repeat on every order, which is what makes the second entity visible.
IF OBJECT_ID('CustomerOrdersFlat') IS NOT NULL DROP TABLE CustomerOrdersFlat;

CREATE TABLE CustomerOrdersFlat (
    RowId         int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    CustomerName  nvarchar(120) NOT NULL,
    CustomerEmail nvarchar(256) NOT NULL,
    CustomerPhone nvarchar(30)  NOT NULL,
    OrderRef      nvarchar(20)  NOT NULL,
    PlacedOn      date          NOT NULL,
    TotalZar      decimal(10,2) NOT NULL
);
GO

INSERT INTO CustomerOrdersFlat (CustomerName, CustomerEmail, CustomerPhone, OrderRef, PlacedOn, TotalZar)
VALUES
    ('Thandi Mokoena', 'thandi@example.co.za', '082 555 0114', 'ORD-2001', '2026-03-02',  1240.00),
    ('Thandi Mokoena', 'thandi@example.co.za', '082 555 0114', 'ORD-2002', '2026-03-19',   485.50),
    ('Thandi Mokoena', 'thandi@example.co.za', '082 555 0114', 'ORD-2007', '2026-04-11',  2310.00),
    ('Pieter van Wyk', 'pieter@example.co.za', '083 555 0192', 'ORD-2003', '2026-03-05',   799.99),
    ('Pieter van Wyk', 'pieter@example.co.za', '083 555 0192', 'ORD-2009', '2026-04-22',   150.00);
GO
```

- [ ] **Step 2: Write the manifest**

```json
{
  "id": "d-b-01-what-a-data-model-is",
  "track": "design",
  "kind": "design",
  "level": "beginner",
  "order": 1,
  "title": "What a Data Model Is",
  "description": "A data model is three things and no more: entities, the attributes that describe them, and the relationships between them. Why it matters: almost every design mistake later in this course is really a first-step mistake — two different things kept in one place, or one thing split across two.",
  "topics": ["entities", "attributes", "relationships", "modelling"],
  "estimatedMinutes": 15,
  "steps": [
    { "kind": "read", "anchor": "scenario" },
    { "kind": "canvas", "prompt": "Split the flat table into Customers and Orders, give each the attributes that belong to it, and connect them." },
    { "kind": "sql", "prompt": "Run the DDL, move the rows across, and confirm two customers now exist once each rather than five times between them." }
  ],
  "hints": [
    "Read the columns and ask 'what is this a fact about?'. CustomerName is a fact about a customer. PlacedOn is a fact about an order. That question is the whole technique.",
    "The side that has many of the other is the side that carries the key. One customer has many orders, so CustomerId goes on Orders — never OrderId on Customers.",
    "On the canvas, drag from the edge of one table to the other to create the relationship. The key column is added to the table you drag to."
  ],
  "startingModel": {
    "entities": [
      {
        "id": "e-customers",
        "name": "Customers",
        "x": 120,
        "y": 100,
        "attributes": [
          { "name": "CustomerId", "dataType": "int", "isPrimaryKey": true, "isIdentity": true, "nullable": false }
        ]
      },
      {
        "id": "e-orders",
        "name": "Orders",
        "x": 480,
        "y": 100,
        "attributes": [
          { "name": "OrderId", "dataType": "int", "isPrimaryKey": true, "isIdentity": true, "nullable": false }
        ]
      }
    ],
    "relationships": []
  },
  "designConditions": [
    { "type": "entityExists", "table": "Customers" },
    { "type": "entityExists", "table": "Orders" },
    { "type": "columnExists", "table": "Customers", "column": "Email" },
    { "type": "primaryKey", "table": "Orders" },
    { "type": "foreignKey", "table": "Orders", "references": "Customers" }
  ],
  "references": [],
  "startingQuery": "SELECT * FROM CustomerOrdersFlat ORDER BY CustomerName, PlacedOn;",
  "passConditions": [],
  "azureUnsupported": false
}
```

Both entities are pre-placed but **the relationship is not** — the learner draws it. That is deliberate: producing the answer, even wrongly, retains better than recognising it.

Before writing, confirm the exact property name the `foreignKey` rule expects for the referenced table by reading `DesignEvaluator.ForeignKey` and the `RuleSpec` record in `api/SqlPerf.Api/Models/Contracts.cs`. The manifest above assumes `"references"`; if `RuleSpec` names it something else (e.g. `refTable`), use that instead. Getting this wrong produces a silently failing condition.

The narrative must:
- Define entity ("a thing you keep facts about"), attribute ("one fact about it") and relationship ("how two entities connect") in `## The concept`.
- State the key-side rule outright in `## What to look for`: *the side that has many of the other is the side that carries the key — an order belongs to one customer, so the key goes on Orders*. Say plainly that module 5 explains why; module 1 is just telling you.
- **State the trade-off:** entity-spotting is judgement, not a procedure. "Is an address an entity or three attributes on the customer?" has no universal answer — it depends on whether you ever need two of them. Say that module 1 has no rule for it rather than implying one exists.
- In `## How this is graded`, describe only the five conditions listed.

- [ ] **Step 3: Write the solution**

```sql
-- Two entities, because there are two different kinds of thing in the flat table.
CREATE TABLE Customers (
    CustomerId int           NOT NULL IDENTITY(1,1),
    FullName   nvarchar(120) NOT NULL,
    Email      nvarchar(256) NOT NULL,
    Phone      nvarchar(30)  NOT NULL,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerId)
);

-- One customer has many orders, so the key lives here, on the many side.
CREATE TABLE Orders (
    OrderId    int           NOT NULL IDENTITY(1,1),
    CustomerId int           NOT NULL,
    OrderRef   nvarchar(20)  NOT NULL,
    PlacedOn   date          NOT NULL,
    TotalZar   decimal(10,2) NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY (OrderId),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerId) REFERENCES Customers (CustomerId)
);

-- Each customer arrives once, however many orders they placed.
INSERT INTO Customers (FullName, Email, Phone)
SELECT DISTINCT CustomerName, CustomerEmail, CustomerPhone FROM CustomerOrdersFlat;

INSERT INTO Orders (CustomerId, OrderRef, PlacedOn, TotalZar)
SELECT c.CustomerId, f.OrderRef, f.PlacedOn, f.TotalZar
FROM CustomerOrdersFlat f
JOIN Customers c ON c.Email = f.CustomerEmail;

-- Two rows, not five:  SELECT COUNT(*) FROM Customers;
```

- [ ] **Step 4: Register in the roadmap**

```ts
      { n: 1, title: "What a data model is", blurb: "Entities, attributes and relationships — the three things every model is made of.", id: "d-b-01-what-a-data-model-is" },
```

- [ ] **Step 5: Restart the API and confirm the module loads**

```bash
docker compose restart api
sleep 10
curl -s http://localhost:5080/api/modules/d-b-01-what-a-data-model-is | head -c 200
```

Expected: module JSON, not a 404.

- [ ] **Step 6: Verify the check FAILS without the relationship**

This is the important negative test: the two tables exist but are not connected.

```bash
curl -s -X POST http://localhost:5080/api/modules/d-b-01-what-a-data-model-is/check \
  -H 'Content-Type: application/json' \
  -d '{"sql":"CREATE TABLE Customers (CustomerId int NOT NULL IDENTITY(1,1), Email nvarchar(256) NOT NULL, CONSTRAINT PK_Customers PRIMARY KEY (CustomerId)); CREATE TABLE Orders (OrderId int NOT NULL IDENTITY(1,1), CONSTRAINT PK_Orders PRIMARY KEY (OrderId));"}' \
  | jq '.evaluation.passed, [.evaluation.conditions[] | {label, passed}]'
```

Expected: `false`, with only the `foreignKey` condition failing. If `foreignKey` passes here, the rule is not reading what you think — go back and check the property name from Step 2.

- [ ] **Step 7: Verify the check PASSES on the solution**

```bash
curl -s -X POST http://localhost:5080/api/modules/d-b-01-what-a-data-model-is/check \
  -H 'Content-Type: application/json' \
  -d "$(jq -Rn --rawfile sql lessons/design/beginner/d-b-01-what-a-data-model-is/solution.sql '{sql: $sql}')" \
  | jq '.evaluation.passed, [.evaluation.conditions[] | {label, passed}]'
```

Expected: `true`, all five conditions passing.

- [ ] **Step 8: Verify the backwards relationship fails informatively**

A learner who wires the key to the wrong side is the case this module's design deliberately allows. Confirm they get a failure they can act on rather than a crash:

```bash
curl -s -X POST http://localhost:5080/api/modules/d-b-01-what-a-data-model-is/check \
  -H 'Content-Type: application/json' \
  -d '{"sql":"CREATE TABLE Orders (OrderId int NOT NULL IDENTITY(1,1), CONSTRAINT PK_Orders PRIMARY KEY (OrderId)); CREATE TABLE Customers (CustomerId int NOT NULL IDENTITY(1,1), Email nvarchar(256) NOT NULL, OrderId int NOT NULL, CONSTRAINT PK_Customers PRIMARY KEY (CustomerId), CONSTRAINT FK_Customers_Orders FOREIGN KEY (OrderId) REFERENCES Orders (OrderId));"}' \
  | jq '.evaluation.passed, [.evaluation.conditions[] | select(.passed==false) | .label]'
```

Expected: `false`, and the failing label names the missing `Orders → Customers` foreign key. Read the label as a learner would. If it does not make the direction obvious, strengthen hint 2 in the manifest — do not weaken the condition.

- [ ] **Step 9: Run it twice**

Repeat the Step 7 command unchanged. Expected: `true` again, no "already an object named" error.

- [ ] **Step 10: Commit**

```bash
git add lessons/design/beginner/d-b-01-what-a-data-model-is web/src/design/roadmap.ts
git commit -m "Add the what-a-data-model-is module

Module 1 splits a flat table into Customers and Orders. Both entities
are pre-placed but the relationship is not: the learner draws it, and a
key wired to the wrong side fails the check. That is the intended path
rather than a rough edge, so the narrative states the rule outright and
module 5 explains it.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Module 10 — the order-entry capstone

**Files:**
- Create: `lessons/design/beginner/d-b-10-capstone-order-entry/seed.sql`
- Create: `lessons/design/beginner/d-b-10-capstone-order-entry/manifest.json`
- Create: `lessons/design/beginner/d-b-10-capstone-order-entry/solution.sql`
- Modify: `web/src/design/roadmap.ts:27` (add `id` to the `n: 10` entry)

**Interfaces:**
- Consumes: the vocabulary from modules 1–9. Assumes the learner has met entities, data types, keys, 1:M, M:M, nullability and constraints.
- Produces: module id `d-b-10-capstone-order-entry`. Final module of the Beginner level.

- [ ] **Step 1: Write the seed**

The capstone starts from a brief, not from data to fix. The seed provides a reference price list the learner reads but does not model, so `Products` has something to be checked against.

```sql
-- A price list the business already publishes. The learner reads it to see what
-- a product is; they do not model this table.
IF OBJECT_ID('PriceListExtract') IS NOT NULL DROP TABLE PriceListExtract;

CREATE TABLE PriceListExtract (
    Sku        nvarchar(20)  NOT NULL PRIMARY KEY,
    ProductName nvarchar(120) NOT NULL,
    ListPrice  decimal(10,2) NOT NULL,
    Discontinued bit         NOT NULL
);
GO

INSERT INTO PriceListExtract (Sku, ProductName, ListPrice, Discontinued) VALUES
    ('SKU-0001', 'Rooibos tea, 250g',      64.99, 0),
    ('SKU-0002', 'Enamel mug, 350ml',     129.00, 0),
    ('SKU-0003', 'Cast iron pan, 24cm',   749.00, 0),
    ('SKU-0004', 'Linen apron',           329.50, 1),
    ('SKU-0005', 'Beeswax wrap, set of 3', 189.00, 0);
GO
```

- [ ] **Step 2: Write the manifest**

`startingModel` is **empty** — `{ "entities": [], "relationships": [] }`. The capstone is the first time the learner faces a blank canvas, which is what forces retrieval rather than recognition.

```json
{
  "id": "d-b-10-capstone-order-entry",
  "track": "design",
  "kind": "design",
  "level": "beginner",
  "order": 10,
  "title": "Capstone: An Order-Entry System",
  "description": "Everything in this level, applied once, from a written brief and an empty canvas. Why it matters: the modules gave you one idea at a time — a real design is deciding which ideas apply, in what order, to a description written by someone who does not know what a foreign key is.",
  "topics": ["modelling", "relationships", "junction tables", "constraints"],
  "estimatedMinutes": 45,
  "steps": [
    { "kind": "read", "anchor": "scenario" },
    { "kind": "canvas", "prompt": "Model the whole system from the brief. Nothing is drawn for you." },
    { "kind": "sql", "prompt": "Run the DDL, then place one order with two lines and prove the total can be recalculated from what you stored." }
  ],
  "hints": [
    "Start by listing the nouns in the brief: customer, order, line, product. Four nouns, four tables — that is not always true, but here it is.",
    "An order has many lines and a product appears on many lines. The line is where those two meet, which makes OrderLines a junction table that also carries facts of its own.",
    "Read 'the price charged at the time' again. If the price lives only on Products, what happens to last year's orders when someone edits it?"
  ],
  "startingModel": { "entities": [], "relationships": [] },
  "designConditions": [
    { "type": "entityExists", "table": "Customers" },
    { "type": "entityExists", "table": "Orders" },
    { "type": "entityExists", "table": "OrderLines" },
    { "type": "entityExists", "table": "Products" },
    { "type": "primaryKey", "table": "Customers" },
    { "type": "primaryKey", "table": "Orders" },
    { "type": "primaryKey", "table": "OrderLines" },
    { "type": "primaryKey", "table": "Products" },
    { "type": "foreignKey", "table": "Orders", "references": "Customers" },
    { "type": "foreignKey", "table": "OrderLines", "references": "Orders" },
    { "type": "foreignKey", "table": "OrderLines", "references": "Products" },
    { "type": "naturalKeyUnique", "table": "Products", "columns": ["Sku"] },
    { "type": "columnExists", "table": "OrderLines", "column": "UnitPriceZar", "pattern": "decimal" },
    { "type": "checkConstraintExists", "table": "OrderLines", "column": "Quantity" },
    { "type": "notNullable", "table": "Orders", "column": "PlacedOn" }
  ],
  "references": [],
  "startingQuery": "SELECT * FROM PriceListExtract ORDER BY Sku;",
  "passConditions": [],
  "azureUnsupported": false
}
```

Use the same `foreignKey` property name confirmed in Task 2 Step 2.

The `## Scenario` section carries the brief, written as prose a businessperson would say — not a specification:

> Customers place orders. An order is placed on a date, and is either still being
> picked, or has shipped — in which case we know when. An order has several lines
> on it. Each line is for one product, at some quantity, at the price we charged
> for it at the time. Products have a stock code we print on labels, a name, and a
> current list price.

The narrative must:
- Leave the modelling to the learner. Do not enumerate the four tables in the narrative — the hints do that progressively, and naming them up front removes the whole exercise.
- In `## What to look for`, draw out the one genuinely new idea: **unit price belongs on the line, not on the product**, because the price charged then is not the price now. Frame it as a question ("what happens to last year's orders when someone edits a price?") rather than an instruction.
- Explain that `OrderLines` is a junction table that carries its own facts — the first time in the level a table exists for a *relationship* rather than for a thing.
- Discuss `ShippedOn` being NULL until despatch, referring back to module 8.
- **State the trade-offs:** storing the charged price duplicates data that usually matches the list price, and that is correct anyway — the two look the same but mean different things. Also note that four nouns mapping to four tables is a happy accident of this brief, not a method.
- Mention one-to-one is not present here, and say why: this domain has no honest one-to-one, and inventing one to complete the set would be a worse lesson than leaving it out.
- In `## How this is graded`, describe only the fifteen conditions listed. It must explicitly **not** imply that indexing or the nullability of `ShippedOn` were checked — neither is.

- [ ] **Step 3: Write the solution**

```sql
-- Four entities: three things, and one relationship that carries its own facts.
CREATE TABLE Customers (
    CustomerId int           NOT NULL IDENTITY(1,1),
    FullName   nvarchar(120) NOT NULL,
    Email      nvarchar(256) NOT NULL,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerId),
    CONSTRAINT UQ_Customers_Email UNIQUE (Email)
);

CREATE TABLE Products (
    ProductId    int           NOT NULL IDENTITY(1,1),
    Sku          nvarchar(20)  NOT NULL,
    Name         nvarchar(120) NOT NULL,
    ListPriceZar decimal(10,2) NOT NULL,
    Discontinued bit           NOT NULL CONSTRAINT DF_Products_Discontinued DEFAULT (0),
    CONSTRAINT PK_Products PRIMARY KEY (ProductId),
    -- The code printed on labels. Not the identifier, but it must not repeat.
    CONSTRAINT UQ_Products_Sku UNIQUE (Sku),
    CONSTRAINT CK_Products_ListPriceZar CHECK (ListPriceZar >= 0)
);

CREATE TABLE Orders (
    OrderId    int  NOT NULL IDENTITY(1,1),
    CustomerId int  NOT NULL,
    PlacedOn   date NOT NULL,
    -- NULL means "not shipped yet" — genuinely unknown, not zero. Module 8.
    ShippedOn  date NULL,
    CONSTRAINT PK_Orders PRIMARY KEY (OrderId),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerId) REFERENCES Customers (CustomerId),
    CONSTRAINT CK_Orders_ShippedOn CHECK (ShippedOn IS NULL OR ShippedOn >= PlacedOn)
);

-- The junction. It exists because an order has many products and a product is on
-- many orders — but it also carries facts of its own, which is what makes it a
-- table rather than a pair of keys.
CREATE TABLE OrderLines (
    OrderLineId  int           NOT NULL IDENTITY(1,1),
    OrderId      int           NOT NULL,
    ProductId    int           NOT NULL,
    Quantity     int           NOT NULL,
    -- The price CHARGED, captured here. Products.ListPriceZar is the price NOW.
    -- They usually match, and they are not the same fact.
    UnitPriceZar decimal(10,2) NOT NULL,
    CONSTRAINT PK_OrderLines PRIMARY KEY (OrderLineId),
    CONSTRAINT FK_OrderLines_Orders   FOREIGN KEY (OrderId)   REFERENCES Orders (OrderId),
    CONSTRAINT FK_OrderLines_Products FOREIGN KEY (ProductId) REFERENCES Products (ProductId),
    CONSTRAINT CK_OrderLines_Quantity     CHECK (Quantity > 0),
    CONSTRAINT CK_OrderLines_UnitPriceZar CHECK (UnitPriceZar >= 0),
    -- The same product twice on one order should be one line with quantity 2.
    CONSTRAINT UQ_OrderLines_Order_Product UNIQUE (OrderId, ProductId)
);

-- Products come from the published list.
INSERT INTO Products (Sku, Name, ListPriceZar, Discontinued)
SELECT Sku, ProductName, ListPrice, Discontinued FROM PriceListExtract;

INSERT INTO Customers (FullName, Email) VALUES ('Thandi Mokoena', 'thandi@example.co.za');

INSERT INTO Orders (CustomerId, PlacedOn, ShippedOn)
VALUES ((SELECT CustomerId FROM Customers WHERE Email = 'thandi@example.co.za'), '2026-04-11', NULL);

INSERT INTO OrderLines (OrderId, ProductId, Quantity, UnitPriceZar)
SELECT o.OrderId, p.ProductId, v.Qty, p.ListPriceZar
FROM (VALUES ('SKU-0002', 2), ('SKU-0003', 1)) AS v(Sku, Qty)
JOIN Products p ON p.Sku = v.Sku
CROSS JOIN (SELECT TOP 1 OrderId FROM Orders ORDER BY OrderId DESC) o;

-- The order total is derivable rather than stored, so it cannot disagree with
-- its own lines:
--   SELECT o.OrderId, SUM(l.Quantity * l.UnitPriceZar) AS TotalZar
--     FROM Orders o JOIN OrderLines l ON l.OrderId = o.OrderId
--    GROUP BY o.OrderId;
```

- [ ] **Step 4: Register in the roadmap**

```ts
      { n: 10, title: "Capstone: an order-entry system", blurb: "Model the whole thing end to end, from a written brief.", id: "d-b-10-capstone-order-entry" },
```

- [ ] **Step 5: Restart the API and confirm the module loads**

```bash
docker compose restart api
sleep 10
curl -s http://localhost:5080/api/modules/d-b-10-capstone-order-entry | head -c 200
```

Expected: module JSON, not a 404.

- [ ] **Step 6: Verify the check FAILS on a partial model**

Three of the four tables, no junction. This is the most likely wrong answer and must fail clearly.

```bash
curl -s -X POST http://localhost:5080/api/modules/d-b-10-capstone-order-entry/check \
  -H 'Content-Type: application/json' \
  -d '{"sql":"CREATE TABLE Customers (CustomerId int NOT NULL IDENTITY(1,1), CONSTRAINT PK_Customers PRIMARY KEY (CustomerId)); CREATE TABLE Products (ProductId int NOT NULL IDENTITY(1,1), Sku nvarchar(20) NOT NULL, CONSTRAINT PK_Products PRIMARY KEY (ProductId), CONSTRAINT UQ_Products_Sku UNIQUE (Sku)); CREATE TABLE Orders (OrderId int NOT NULL IDENTITY(1,1), CustomerId int NOT NULL, PlacedOn date NOT NULL, CONSTRAINT PK_Orders PRIMARY KEY (OrderId), CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerId) REFERENCES Customers (CustomerId));"}' \
  | jq '.evaluation.passed, [.evaluation.conditions[] | select(.passed==false) | .label]'
```

Expected: `false`, with the failures all naming `OrderLines`. Confirm no condition about `Customers`, `Products` or `Orders` fails — if one does, that condition is asserting more than the brief asked for.

- [ ] **Step 7: Verify the check PASSES on the solution**

```bash
curl -s -X POST http://localhost:5080/api/modules/d-b-10-capstone-order-entry/check \
  -H 'Content-Type: application/json' \
  -d "$(jq -Rn --rawfile sql lessons/design/beginner/d-b-10-capstone-order-entry/solution.sql '{sql: $sql}')" \
  | jq '.evaluation.passed, [.evaluation.conditions[] | {label, passed}]'
```

Expected: `true`, all fifteen conditions passing.

- [ ] **Step 8: Verify the reset path handles cross-table foreign keys**

This module has three foreign keys across four tables, which is the case that originally broke Reset. Run the Step 7 command a second time, unchanged.

Expected: `true` again. A failure mentioning "could not drop object ... because it is referenced by a FOREIGN KEY constraint" means `DropSchemaObjectsAsync` has regressed — its FK-first drop pass is load-bearing and must not be removed.

- [ ] **Step 9: Verify the derived total works**

The SQL step promises the total is recalculable. Prove it:

```bash
curl -s -X POST http://localhost:5080/api/modules/d-b-10-capstone-order-entry/check \
  -H 'Content-Type: application/json' \
  -d '{"sql":"SELECT o.OrderId, SUM(l.Quantity * l.UnitPriceZar) AS TotalZar FROM Orders o JOIN OrderLines l ON l.OrderId = o.OrderId GROUP BY o.OrderId;"}' | jq '.error'
```

Expected: `null`. Note this runs against whatever the previous check left in the schema, so run it directly after Step 7.

- [ ] **Step 10: Commit**

```bash
git add lessons/design/beginner/d-b-10-capstone-order-entry web/src/design/roadmap.ts
git commit -m "Add the order-entry capstone

The capstone starts from an empty canvas and a brief written as prose,
so the learner does the modelling rather than transcribing a spec. The
one new idea is that unit price belongs on the line and not on the
product, which falls out of the junction-with-payload shape.

One-to-one is discussed but not graded: this domain has no honest
one-to-one, and inventing one to complete the set would teach worse
than leaving it out.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Fact-check pass, browser verification and PR

**Files:**
- Modify: any of the three manifests, if the fact-check finds corrections.

**Interfaces:**
- Consumes: all three modules from Tasks 1–3.
- Produces: a pull request against `main`.

- [ ] **Step 1: Second fact-check pass over every technical claim**

Re-read all three narratives and list every factual assertion about SQL Server. For each, confirm it against Microsoft Learn via the `microsoft_docs_search` MCP tool. **Apply corrections rather than noting them.**

Claims that must be checked because they are easy to get subtly wrong:
- The one-part name resolution order, and that an error (not a NULL) results when the object is in neither schema.
- That schema permissions apply to objects added to the schema later.
- That `UNIQUE` permits one NULL and can be the target of a foreign key.
- That a `CHECK` rejects only FALSE, so NULL passes it.
- Anything asserted about `IDENTITY`, `date` vs `datetime2`, or `decimal` precision.

- [ ] **Step 2: Confirm the roadmap now shows Beginner as complete**

```bash
grep -c "id:" web/src/design/roadmap.ts
```

Expected: `10` — the seven pre-existing modules plus the three added here. Any other number means a registration step was missed.

- [ ] **Step 3: Build the web app**

```bash
cd web && npm run build && cd ..
```

Expected: a clean build. A TypeScript error here almost certainly means a malformed roadmap entry.

- [ ] **Step 4: Verify all three modules in a real browser**

A green build proves nothing about the running app. Rebuild and hard-reload — a plain reload serves the old bundle and will have you debugging a fix that already worked.

```bash
docker compose up -d --build web
```

Then at `http://localhost:5173`, for each of modules 1, 2 and 10:
- Open the module from the design roadmap and confirm the narrative renders with no raw `\n` or broken markdown.
- Confirm the canvas opens on the intended starting model (module 10 must open **empty**).
- Complete the module on the canvas and press Check. Confirm it passes.
- Press Check a second time. Confirm it still passes.
- Check the browser console for errors, not just the screenshot.

Reload with cache ignored each time. In Chrome DevTools MCP that is `reload` with `ignoreCache: true`.

- [ ] **Step 5: Confirm the deploy will actually ship the content**

Lesson content has no csproj content items, so it only reaches production via an explicit copy step. Confirm it is still there:

```bash
grep -n "cp -r lessons" .github/workflows/ci.yml
```

Expected: a line copying `lessons` into the publish directory. If it is missing, the modules will build green and never appear in production — restore it before merging.

- [ ] **Step 6: Push and open the PR**

```bash
git push -u origin feat/beginner-completion
gh pr create --title "Complete the Beginner level of the design track" --body "$(cat <<'EOF'
Adds the three remaining Beginner modules, taking the design track's first level from 7 of 10 to complete.

- **Module 1 — what a data model is.** Splits a flat table into Customers and Orders. Both entities are pre-placed; the learner draws the relationship, and a key on the wrong side fails the check. That is the intended path, so the narrative states the rule outright and module 5 explains it.
- **Module 2 — tables, rows, columns and schemas.** Uses the learner's own module schema as the specimen. The one-part name fallback and schema permission inheritance are cited to Microsoft Learn.
- **Module 10 — order-entry capstone.** Empty canvas, prose brief, four tables. The new idea is that unit price belongs on the line rather than the product.

Content only — no API, evaluator or frontend changes. Each module was verified by posting its own `solution.sql` to `/api/modules/{id}/check` and asserting every condition passes, then completed by hand in the browser.

One-to-one (module 6) is discussed in the capstone but not graded: the domain has no honest one-to-one, and inventing one to complete the set would teach worse than leaving it out. Indexing foreign keys is likewise left to module 23.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 7: Do not merge without saying so**

Merging to `main` auto-deploys to Azure. Report the PR URL and stop — the merge is Johan's call. After any merge, check the live site rather than assuming: the API cold-starts and the free-tier database auto-pauses, so probe `/api/health` two or three times before concluding anything is broken.

---

## Notes for the implementer

**On writing narratives.** Read `d-b-09-constraints-as-documentation/manifest.json` first and match its voice: concrete scenario, a named cost for each mistake, and a stated trade-off in every section. The narrative is a single JSON string with `\n` escapes — write it in a scratch file as real markdown, then encode it, rather than composing escaped JSON by hand.

**On grading honesty.** The `## How this is graded` section is the one place it is easy to lie by accident. Say what the listed conditions check and nothing more. Where grading is a proxy for the real idea — as it is throughout the capstone — say so in the narrative.

**On the `references` array.** Every manifest in this plan ships with `"references": []` as a starting point, and leaving it empty is only acceptable where the module makes no SQL Server-specific factual claim. Module 2 must have references — its whole content is engine behaviour. Modules 1 and 10 are mostly modelling judgement, but any sentence asserting how SQL Server behaves (identity, `date` vs `datetime2`, what `UNIQUE` permits, how a `CHECK` treats NULL) needs a citation next to it. Task 4 Step 1 is the backstop, not the first pass.

**If a rule does not behave as expected**, read `api/SqlPerf.Api/Services/DesignEvaluator.cs` rather than guessing. Each rule is a short method and the property names it reads are visible there.

**One naming note:** the spec called the capstone's price column `OrderLines.UnitPrice`; this plan uses `UnitPriceZar` throughout to match the currency-suffixed convention already used by `PriceZar` and `TotalZar` in existing modules. The manifest condition, the solution and the narrative all use `UnitPriceZar` — keep them in step.
