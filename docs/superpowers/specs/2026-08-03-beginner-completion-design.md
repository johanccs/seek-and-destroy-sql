# Beginner completion — modules 1, 2 and 10

Date: 2026-08-03
Status: approved, not yet implemented
Scope: the last three unauthored Beginner modules of the Database Design Hub

## Goal

Take the Beginner level of the design track from 7 of 10 modules to complete. Modules 3–9
already ship. This spec covers module 1 (what a data model is), module 2 (tables, rows,
columns and schemas) and module 10 (the order-entry capstone).

Completing Beginner is the nearest milestone that turns the design track from "partial" into
"one finished level", and the capstone is the first end-to-end proof that the grading model
works against a written brief rather than a guided exercise.

## Constraints this design works within

**Grading reads the real database, never the canvas.** The learner models, the server generates
DDL, `SqlExecutor` runs it in the module's isolated schema, `SchemaReader` reads it back, and
`DesignEvaluator` grades the engine's own metadata.

**`DesignEvaluator` has exactly eleven rules**, all of which assert a schema fact:
`entityExists`, `columnExists`, `primaryKey`, `notNullable`, `hasDefault`,
`checkConstraintExists`, `surrogateKey`, `naturalKeyUnique`, `foreignKey`, `indexOnFk`,
`namingConvention`. There is no rule that grades comprehension, so every module must end in
the learner building something real.

**Content is verified against primary sources before writing, not after.** Claims specific to
SQL Server are checked against Microsoft Learn and cited in the manifest's `references` array.

## Approach

All three modules use the existing `read → canvas → sql` step shape and the existing eleven
rules. **No API, evaluator or frontend changes.** The work is three
`manifest.json` + `seed.sql` + `solution.sql` triples under `lessons/design/beginner/`, plus
three `id` fields added to `web/src/design/roadmap.ts`.

Two alternatives were considered and rejected:

- **A new lighter "explore" module kind** (read + SQL, no canvas, graded on query output) for
  the two conceptual openers. Rejected because the grading contract is itself a teaching
  device: modules 3–9 train the learner that "correct" means the engine agrees, and an opener
  graded more loosely would teach a standard every later module contradicts. It also needs new
  backend and frontend support to make 2 of 10 modules behave differently.
- **Merging modules 1 and 2** into one richer module. Rejected because renumbering churns
  `roadmap.ts`, every manifest `order` field, and `d-b-NN-` ids already live in production.

Delivery order is **2 → 1 → 10**: module 2 is the most self-contained, module 1 needs the most
care in framing, and the capstone depends on vocabulary both establish.

## Module 1 — `d-b-01-what-a-data-model-is`

Order 1. Estimated 15 minutes.

**Seed.** One flat `CustomerOrdersFlat` table where customer name, email and phone repeat on
every order row — five orders across two customers. Deliberately *not* framed as normalization
(module 11's job); framed as "there are clearly two different kinds of thing in here." The
skill being taught is entity-spotting.

**Task.** Split it into `Customers` and `Orders` and connect them.

**The relationship is drawn by the learner, not pre-wired.** This is a deliberate choice in
favour of the generation effect: producing an answer, even a wrong one, retains better than
recognising a correct one, and a learner who wires the key to the wrong side, fails the check
and fixes it has learned "which side carries the key" more durably than being told.

The risk — failing for a reason module 5 hasn't taught yet — is mitigated in narrative rather
than by weakening the task. Module 1 *states* the rule in one sentence ("the side that has many
of the other is the side that carries the key: an order belongs to one customer, so the key
goes on Orders"), backed by a hint. Module 5 then *explains* it, covers cardinality and
referential actions, and applies it where the answer is not handed over.

**Graded (5 conditions).**

| Rule | Target |
|---|---|
| `entityExists` | Customers |
| `entityExists` | Orders |
| `columnExists` | Customers.Email |
| `primaryKey` | Orders |
| `foreignKey` | Orders → Customers |

**Concept section.** Entity = a thing you keep facts about. Attribute = one fact about it.
Relationship = how two entities connect. Plus the honest caveat that entity-spotting is
judgement, not a procedure: "is an address an entity or three attributes?" has no universal
answer, and the module says so rather than pretending module 1 has a rule for it.

## Module 2 — `d-b-02-tables-rows-columns-schemas`

Order 2. Estimated 20 minutes.

**Task.** Build one small `Customers` table — the building is deliberately trivial — then use
SQL to see what the engine actually stored. **The SQL step is the lesson**, and the specimen is
the learner's own sandbox.

```sql
SELECT SCHEMA_NAME() AS my_default_schema;
SELECT name, schema_id FROM sys.schemas;
SELECT t.name, s.name AS schema_name
  FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id;
SELECT name, system_type_id, max_length, is_nullable
  FROM sys.columns WHERE object_id = OBJECT_ID('Customers');
```

**Three teaching points, all source-verified:**

1. **A table is itself a row in `sys.tables`.** The catalog is a database describing a
   database — which is also *why* the grader can read the learner's work back.
2. **Columns are data.** `sys.columns` returns the shape of the table as rows.
3. **One-part name resolution.** Microsoft's documentation: *"When database objects are
   referenced by using a one-part name, SQL Server first looks in the user's default schema.
   If the object is not found there, SQL Server looks next in the `dbo` schema. If the object
   is not in the `dbo` schema, an error is returned."* Shown live, then contrasted with the
   two-part qualified form that skips the guessing.

**The reframe that makes schemas matter:** a schema is not a folder, it is a standing grant.
Permissions applied to a schema are inherited by objects added to it *later*. That is the
actual reason schemas exist, and it is why this app gives every module its own schema with its
own contained user — which the module states out loud rather than hiding.

**Verified precondition.** `SqlExecutor.cs:241` provisions the user as
`CREATE USER [u_<schema>] WITHOUT LOGIN WITH DEFAULT_SCHEMA = [<schema>]`, so `SCHEMA_NAME()`
does return the module's own schema and the headline demo works. The comment at
`SqlExecutor.cs:118` confirms this is deliberate: bare table names in lesson content resolve
via `DEFAULT_SCHEMA`. Module 2 therefore explains the mechanism every other lesson in the app
has silently relied on.

**Graded (4 conditions).**

| Rule | Target |
|---|---|
| `entityExists` | Customers |
| `primaryKey` | Customers |
| `columnExists` | Customers.Email |
| `notNullable` | Customers.Email |

**References to cite.** Ownership and user-schema separation (namespaces, one-part name
resolution, `dbo` as default, permission inheritance); `sys.schemas` catalog view (schemas act
as namespaces or containers); four-part naming `Server.Database.DatabaseSchema.DatabaseObject`.

## Module 10 — `d-b-10-capstone-order-entry`

Order 10. Estimated 45 minutes.

**Empty canvas.** Nothing pre-drawn — the capstone should be the first time the learner faces a
blank page, forcing retrieval rather than recognition.

**Written brief, in prose rather than as a spec:** customers place orders; an order has several
lines; each line is for one product, at a quantity, at the price charged at the time.

**Target shape.** `Customers → Orders → OrderLines ← Products`, where `OrderLines` is a
junction carrying its own payload. This is the highest-value shape in Beginner: it is the first
time a table exists for a *relationship* rather than for a thing.

The one genuinely new idea is that **unit price belongs on the line, not on the product**,
because the price charged then is not the price now. It falls out of the shape rather than
being asserted, which is why the brief mentions "the price charged at the time" and says
nothing further.

**Coverage of the level.** Data types (module 3) via decimal money and date columns; natural
keys (4) via `Products.Sku`; one-to-many (5) via Customers → Orders; many-to-many (7) via the
junction; nullability (8) via `ShippedOn` being NULL until despatch; constraints (9) via the
quantity check. One-to-one (module 6) is discussed in the narrative but not required — the
domain has no honest one-to-one, and inventing one to tick a box would teach the wrong lesson.

**Graded (15 rule entries).**

| Rule | Target |
|---|---|
| `entityExists` | Customers, Orders, OrderLines, Products (4 rules) |
| `primaryKey` | Customers, Orders, OrderLines, Products (4 rules) |
| `foreignKey` | Orders → Customers |
| `foreignKey` | OrderLines → Orders |
| `foreignKey` | OrderLines → Products |
| `naturalKeyUnique` | Products.Sku |
| `columnExists` | OrderLines.UnitPrice, pattern `decimal` |
| `checkConstraintExists` | OrderLines.Quantity |
| `notNullable` | Orders.PlacedOn |

Fifteen entries, since `entityExists` and `primaryKey` each apply to all four tables. The count
may shift by one or two during authoring if a check proves redundant.

**Deliberately not graded.** `indexOnFk` — that is module 23's material, and requiring it here
would assert a performance rule Beginner has not taught. Nullability of `ShippedOn` beyond its
existence — grading the *absence* of a constraint is noise, so the narrative discusses
NULL-as-not-yet-shipped without a rule behind it. The narrative must not imply either was
checked.

## Testing and verification

- Each module's `solution.sql` must produce a schema that passes all of its own
  `designConditions` — the check is run against a live engine, not reasoned about.
- Each module is opened in a browser and completed end to end, including pressing Check twice
  to confirm the schema reset path still works.
- A second fact-check pass over every technical claim before the PR, with corrections applied
  rather than noted.
- `roadmap.ts` renders modules 1, 2 and 10 as built rather than as plan once their `id` fields
  are added.

## Out of scope

The normalization stepper widget, reverse-engineering an existing schema, auto-layout, the AI
tutor on the design track, canvas touch support, and the outstanding `docs/CONTRACT.md` line
stating that `Contracts.cs` wins on conflict. None of these block Beginner completion.
