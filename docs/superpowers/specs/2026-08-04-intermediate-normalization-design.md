# Intermediate level — normalization, modules 11–19

Date: 2026-08-04
Status: approved, not yet implemented
Scope: the nine Intermediate modules of the Database Design Hub, plus the two pieces of
machinery they need

## Goal

Take the design track from one finished level to two. Beginner (modules 1–10) shipped on
2026-08-04. Intermediate is modules **11–19** — nine modules, not ten; the Advanced level
opens at 20 with indexing.

Intermediate is where the track stops teaching one idea per module and starts making a single
cumulative argument: a flat table is decomposed step by step from unnormalized through 1NF,
2NF, 3NF and BCNF, and then — deliberately — partly back again.

## Constraints this design works within

**Grading reads the real database, never the canvas.** The learner models, the server generates
DDL, `SqlExecutor` runs it in the module's isolated schema, `SchemaReader` reads it back, and
`DesignEvaluator` grades the engine's own metadata.

**Normal forms are graded structurally, never semantically.** 2NF, 3NF and BCNF are statements
about functional dependencies, which live in the problem domain and not in `sys.columns`. Each
module grades the *structural fingerprint* of the correct decomposition — this table exists,
this column is gone from that one, this foreign key connects them. This spec must never promise
a general-purpose normal-form checker, and every module's narrative must say plainly that the
grader checks the shape of the result rather than the learner's reasoning.

**Unknown rule types already fail safe.** `DesignEvaluator` returns
`("Unknown rule '<type>'", false, "unsupported")` for a type it does not implement. A manifest
can therefore be authored against a rule that does not exist yet and will go visibly red, which
makes test-first authoring natural rather than bolted on.

**Content is verified against primary sources before writing, not after**, and cited in the
manifest's `references` array.

## Two pieces of machinery come first

Unlike the Beginner level, this level cannot be authored as pure content. Two gaps have to close
before module 11 is written, and both are verifiable against the ten modules that already ship.

### 1. `columnAbsent` — a new evaluator rule

Every one of `DesignEvaluator`'s eleven rules is a positive assertion: something exists.
Normalization needs the opposite. The entire point of decomposing is that a column *left* the
table where it did not belong.

Without this rule, a learner who correctly creates `Course` but leaves `CourseTitle` duplicated
in `Enrolment` passes the module — while committing precisely the error the module teaches. This
is load-bearing, not convenience.

`columnAbsent` takes an entity and a column and passes when the column is not present on that
table in the schema read back from the engine. It is the only new rule this level needs;
`entityExists`, `columnExists`, `primaryKey`, `foreignKey` and `namingConvention` express
everything else.

### 2. A step bar — rendering data that already exists

`ModuleStep` is typed (`kind: "read" | "canvas" | "sql"`), authored in all ten Beginner
manifests, and shipped to the client in `ModuleDetailDto`. **Nothing renders it.**
`ModuleRoute.tsx` renders `narrative` and `hints` only.

The roadmap advertises a "Normalization stepper" for this level, and the honest reading is that
the stepper and this dead field are the same feature. A `<StepBar>` component renders
`module.steps` as a horizontal progress map above the panes; clicking a step focuses the
matching pane (`read` → narrative, `canvas` → canvas, `sql` → SQL).

It is **passive**: nothing locks, nothing gates, and no new state persists. A gated sequence was
rejected — it needs per-step completion state and an escape hatch, and it fights the learner who
already knows the material. Auto-inference was rejected as guesswork that will point at the
wrong step.

Because all ten Beginner modules already author `steps`, this retro-fits the existing level for
free and can be verified against it before a single Intermediate module exists. No manifest, API
or step-kind changes.

## Content architecture: one spine, three escapes

A single deliberately awful flat table, `EnrolmentSheet`, carries modules 11–15 and 17. Each
module decomposes the same data further, so the learner sees cumulative payoff rather than nine
unrelated exercises.

The starting sheet holds, in one table: `StudentId`, `StudentName`, `StudentEmail`,
`Phone1`, `Phone2`, `Phone3`, `Skills` (comma-separated), `CourseCode`, `CourseTitle`,
`Credits`, `InstructorName`, `InstructorOffice`, `RoomCode`, `RoomBuilding`, `RoomCapacity`,
`Term`, `Grade`.

Course enrolments earn the spine because they generate every violation the level teaches
*naturally* rather than by contrivance: a repeating group, a partial dependency on a composite
key, two transitive dependencies, and the overlapping-candidate-key case that 3NF permits. The
domain is also clearly distinct from the Beginner capstone's order-entry system.

| #  | Module | Vehicle | Structural fingerprint graded |
|----|--------|---------|-------------------------------|
| 11 | Why normalize — the anomalies | Spine, still flat | The single table that fixes the insert anomaly |
| 12 | 1NF: repeating groups | Spine | `Phone1..3` and `Skills` absent; child tables and FKs exist |
| 13 | 2NF: partial dependencies | Spine | Composite key present; `CourseTitle`/`Credits` moved to `Course` |
| 14 | 3NF: transitive dependencies | Spine | `Room` and `Instructor` extracted; transitive columns absent |
| 15 | BCNF: when 3NF isn't enough | Spine, extended | Overlapping candidate keys resolved |
| 16 | 4NF and 5NF | Own scenario | A multivalued dependency split; a join dependency recognised |
| 17 | Denormalizing on purpose | Spine's 3NF result | A reporting rollup, plus a measured cost |
| 18 | Naming and schema organisation | Own scenario | `namingConvention`; schemas as namespaces |
| 19 | Capstone: spreadsheet to BCNF | Unseen table | The full arc, nothing drawn |

### The functional dependencies, stated once

Everything below depends on these being right, so they are written out rather than assumed.
Verified 2026-08-04 against the standard characterisation of 3NF-but-not-BCNF: a relation
`R(A,B,C)` with candidate keys `{A,B}` and `{A,C}` and the dependency `B → C` is in 3NF because
`C` is *prime*, and violates BCNF because `B` is not a superkey.

`EnrolmentSheet` key: `(StudentId, CourseCode, Term)`.

| Dependency | Violates | Fixed in |
|---|---|---|
| `Phone1..3`, `Skills` are repeating groups | 1NF | 12 |
| `StudentId → StudentName, StudentEmail` | 2NF (partial) | 13 |
| `CourseCode → CourseTitle, Credits` | 2NF (partial) | 13 |
| `(CourseCode, Term) → RoomCode, InstructorName` | 2NF (partial) | 13 |
| `RoomCode → RoomBuilding, RoomCapacity` | 3NF (transitive, inside `CourseOffering`) | 14 |
| `InstructorName → InstructorOffice` | 3NF (transitive, inside `CourseOffering`) | 14 |
| `Instructor → CourseCode`, with CKs `{Student, Course}` and `{Student, Instructor}` | BCNF | 15 |

**Instructor lives at the offering level, not on `Course`.** An earlier draft put
`CourseCode → InstructorName` on the `Course` table, which contradicts module 15 — that module
needs a course to have *several* instructors while each instructor teaches only one course. Both
cannot be true. Putting the instructor on `(CourseCode, Term)` removes the contradiction and is
also the more truthful model: who teaches a course varies by term.

**Module 15 extends the spine rather than re-using it unchanged.** It adds a fact the earlier
modules had no reason to record — *which* instructor taught *this* student — producing
`(StudentId, CourseCode, InstructorName)` with the overlapping candidate keys above. This is a
genuine addition to the model, not a contrivance.

**Module 15 must teach the trade-off, not just the decomposition.** Splitting into
`(Instructor, CourseCode)` and `(StudentId, Instructor)` is lossless but **not
dependency-preserving**: the dependency `(StudentId, CourseCode) → Instructor` can no longer be
enforced by either table alone. BCNF is the one normal form that can cost you a constraint, and
saying so is the honest version of this module. Never present BCNF as strictly better than 3NF.

### Why three modules leave the spine

**16 (4NF/5NF)** needs genuinely different-shaped data. A multivalued dependency requires two
independent multivalued facts about one key; a join dependency requires a three-way relationship
that decomposes losslessly into three binaries but not two. Contorting the enrolment sheet to
produce these would teach the concepts badly. This module teaches *recognition* — these forms
are rare in practice and the module says so rather than implying every schema should be drilled
to 5NF.

**18 (naming)** is about consistency across a whole schema, which a mid-decomposition spine
cannot show. It uses the existing `namingConvention` rule and calls back to module 2's treatment
of schemas as namespaces.

**19 (capstone)** must use an unseen table or it grades recall rather than transfer. A clinic
appointments sheet gives a fresh domain with the same violation profile.

### Module 11 is graded, not merely explored

Module 11 shows the three anomalies with real DML against the flat table before any rule is
named. It would be tempting to leave it ungraded, but the level's whole claim is that
normalization solves a concrete problem, so the module ends by having the learner build the one
table that makes the insert anomaly impossible — a real, minimal, gradeable first decomposition
that motivates everything after it.

### Module 17 must stay honest

Denormalization is where folklore is thickest. This module adds a reporting rollup to the 3NF
result and **measures** the effect with real reads rather than asserting a benefit, and it
states the cost — the rollup can now disagree with the rows it summarises. It is the natural
bridge to the performance track.

## Verification

Per module, matching the Beginner level's precedent:

- **Red–green:** the check fails against `seed.sql` and passes against `solution.sql`. Both
  directions are run; a rule that cannot fail is not grading anything.
- **Machinery first:** `columnAbsent` and `<StepBar>` are verified against existing Beginner
  modules before any Intermediate content depends on them.
- **Fact-check before writing:** Codd for 1NF–3NF, Boyce–Codd for BCNF, Fagin for 4NF and 5NF,
  Microsoft Learn for anything SQL Server-specific. Cited in `references`. A second pass before
  shipping, applying corrections rather than noting them.
- **Browser:** hard reload with `ignoreCache`, check the console, confirm markdown renders
  unescaped and the capstone opens on an empty canvas.

## Build order

1. `columnAbsent` rule (test-first; it can be proven against a Beginner module's schema).
2. `<StepBar>` (verified against existing modules, which already author `steps`).
3. Modules 11 → 19 in sequence, since each decomposition builds on the previous one.
4. Register all nine `id` fields in `web/src/design/roadmap.ts`.

## Implementation increments

Nine modules and two machinery changes are too much for one plan. The work splits into three
increments, each independently shippable and each leaving the app in a working state:

1. **Machinery** — `columnAbsent` and `<StepBar>`. Ships on its own merit: the step bar improves
   all ten existing Beginner modules whether or not Intermediate ever lands.
2. **The spine** — modules 11–15, the unbroken 1NF → BCNF arc. The largest increment and the
   level's core argument.
3. **The rest** — modules 16, 17, 18 and the capstone 19, plus roadmap registration.

Each increment gets its own implementation plan. This spec covers all three.

## Out of scope

Reverse-engineering an existing schema into a diagram, auto-layout, the AI tutor on the design
track, and touch support on the canvas. The Advanced level (20–28) is a separate spec.
