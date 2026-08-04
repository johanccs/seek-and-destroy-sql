# Intermediate Increment 2 — The Normalization Spine (Modules 11–15)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author modules 11–15 — the unbroken unnormalized → 1NF → 2NF → 3NF → BCNF arc — on one deliberately awful `EnrolmentSheet`, so each decomposition builds on the last.

**Architecture:** Pure content. Each module is a `manifest.json` + `seed.sql` + `solution.sql` triple under `lessons/design/intermediate/`, graded by declarative `designConditions` that the existing `DesignEvaluator` already implements. No API, evaluator or frontend changes — increment 1 shipped the only new rule this level needs (`columnAbsent`).

**Tech Stack:** JSON manifests, T-SQL seed/solution scripts, SQL Server 2022. Content only.

## Global Constraints

- **Grading is structural, never semantic.** 2NF/3NF/BCNF are statements about functional dependencies, which live in the problem domain and not in `sys.columns`. Each module grades the *structural fingerprint* of the correct decomposition. **Every narrative must say so explicitly** — never imply the grader checked the learner's reasoning.
- **Grading reads the real database, never the canvas.** The learner's DDL runs in an isolated schema and `SchemaReader` reads it back.
- **Teach trade-offs, never rules.** Each module states when its own advice is wrong.
- **Verify against primary sources before writing, and cite in the manifest's `references` array.** Codd for 1NF–3NF, Boyce–Codd for BCNF, Microsoft Learn for anything SQL Server-specific.
- **Identifiers are `PascalCase`**, matching the Beginner level.
- **Every module ends in the learner building something real** — there is no rule that grades comprehension.
- Manifest keys, exactly: `id`, `track` (`"design"`), `kind` (`"design"`), `level` (`"intermediate"`), `order`, `title`, `description`, `topics`, `estimatedMinutes`, `narrative`, `steps`, `hints`, `startingQuery`, `startingModel`, `designConditions`, `references`.
- **`foreignKey` rules take `columns` (a list), never `column`.** `DesignEvaluator.ForeignKey` reads only `r.Columns`; a singular `column` is silently ignored and the rule degrades to "any foreign key to that table". `RuleSpec` is a flat bag of optionals, so a wrong key name is never an error — it just grades less than you think.
- **`startingModel` relationships take `fromColumns`/`toColumns` (lists), never the singular forms.** `ErdCanvas` calls `r.fromColumns.forEach(...)` unguarded, so the wrong key name is a canvas crash on load rather than a silent no-op.
- `steps` entries are `{ "kind": "read" | "canvas" | "sql", "prompt"?: string, "anchor"?: string }`. Only the **current** step's prompt renders, so prompts may be a full sentence.

## The functional dependencies — the contract every task grades against

`EnrolmentSheet` candidate key: `(StudentId, CourseCode, Term)`.

| Dependency | Violates | Fixed in |
|---|---|---|
| `Phone1..3`, `Skills` (CSV) are repeating groups | 1NF | 12 |
| `StudentId → StudentName, StudentEmail` | 2NF (partial) | 13 |
| `CourseCode → CourseTitle, Credits` | 2NF (partial) | 13 |
| `(CourseCode, Term) → RoomCode, InstructorName` | 2NF (partial) | 13 |
| `RoomCode → RoomBuilding, RoomCapacity` | 3NF (transitive in `CourseOffering`) | 14 |
| `InstructorName → InstructorOffice` | 3NF (transitive in `CourseOffering`) | 14 |
| `Instructor → CourseCode`, CKs `{Student, Course}` and `{Student, Instructor}` | BCNF | 15 |

**Do not move the instructor onto `Course`.** It belongs on `(CourseCode, Term)`. Putting it on `Course` would mean one instructor per course, contradicting module 15, which needs a course taught by several instructors while each instructor teaches only one.

---

### Task 1: Module 11 — Why normalize: the anomalies

**Files:**
- Create: `lessons/design/intermediate/d-i-11-why-normalize/manifest.json`
- Create: `lessons/design/intermediate/d-i-11-why-normalize/seed.sql`
- Create: `lessons/design/intermediate/d-i-11-why-normalize/solution.sql`

**Interfaces:**
- Produces: the `EnrolmentSheet` table shape that modules 12–15 all inherit. Its column list is fixed here and must not drift.

**What this module argues:** the three anomalies are shown with real DML *before* any normal form is named, because normalization is anomaly-removal and not rule-following. It ends with the single smallest decomposition that makes the insert anomaly impossible.

- [ ] **Step 1: Write `seed.sql`**

```sql
DROP TABLE IF EXISTS EnrolmentSheet;
CREATE TABLE EnrolmentSheet (
    StudentId       int            NOT NULL,
    StudentName     nvarchar(100)  NOT NULL,
    StudentEmail    nvarchar(200)  NOT NULL,
    Phone1          nvarchar(30)   NULL,
    Phone2          nvarchar(30)   NULL,
    Phone3          nvarchar(30)   NULL,
    Skills          nvarchar(400)  NULL,
    CourseCode      nvarchar(12)   NOT NULL,
    CourseTitle     nvarchar(120)  NOT NULL,
    Credits         int            NOT NULL,
    Term            nvarchar(12)   NOT NULL,
    InstructorName  nvarchar(100)  NOT NULL,
    InstructorOffice nvarchar(40)  NOT NULL,
    RoomCode        nvarchar(12)   NOT NULL,
    RoomBuilding    nvarchar(60)   NOT NULL,
    RoomCapacity    int            NOT NULL,
    Grade           nvarchar(2)    NULL,
    CONSTRAINT PK_EnrolmentSheet PRIMARY KEY (StudentId, CourseCode, Term)
);

INSERT INTO EnrolmentSheet VALUES
 (1,'Thandi Mokoena','thandi@example.ac.za','082 555 0101','021 555 0199',NULL,'SQL,Python','DB101','Database Fundamentals',15,'2026S1','Dr Naidoo','B-214','R101','Science Block',60,'A'),
 (2,'Sipho Dlamini','sipho@example.ac.za','083 555 0102',NULL,NULL,'Java','DB101','Database Fundamentals',15,'2026S1','Dr Naidoo','B-214','R101','Science Block',60,'B'),
 (3,'Ayesha Patel','ayesha@example.ac.za','084 555 0103','011 555 0177','072 555 0155','SQL,R,Excel','ST200','Statistics',12,'2026S1','Prof Botha','C-108','R205','Maths Block',40,'A'),
 (1,'Thandi Mokoena','thandi@example.ac.za','082 555 0101','021 555 0199',NULL,'SQL,Python','ST200','Statistics',12,'2026S1','Prof Botha','C-108','R205','Maths Block',40,'B');
```

- [ ] **Step 2: Write `solution.sql`**

The learner extracts `Course` so a course can exist before anyone enrols on it.

```sql
DROP TABLE IF EXISTS Course;
CREATE TABLE Course (
    CourseCode  nvarchar(12)  NOT NULL,
    CourseTitle nvarchar(120) NOT NULL,
    Credits     int           NOT NULL,
    CONSTRAINT PK_Course PRIMARY KEY (CourseCode)
);

INSERT INTO Course (CourseCode, CourseTitle, Credits)
SELECT DISTINCT CourseCode, CourseTitle, Credits FROM EnrolmentSheet;

ALTER TABLE EnrolmentSheet DROP COLUMN CourseTitle;
ALTER TABLE EnrolmentSheet DROP COLUMN Credits;

ALTER TABLE EnrolmentSheet
    ADD CONSTRAINT FK_EnrolmentSheet_Course
    FOREIGN KEY (CourseCode) REFERENCES Course (CourseCode);
```

- [ ] **Step 3: Write the manifest's `designConditions`**

```json
[
  { "type": "entityExists", "table": "Course" },
  { "type": "primaryKey", "table": "Course", "columns": ["CourseCode"] },
  { "type": "columnExists", "table": "Course", "column": "CourseTitle" },
  { "type": "columnExists", "table": "Course", "column": "Credits" },
  { "type": "columnAbsent", "table": "EnrolmentSheet", "column": "CourseTitle" },
  { "type": "columnAbsent", "table": "EnrolmentSheet", "column": "Credits" },
  { "type": "foreignKey", "table": "EnrolmentSheet", "columns": ["CourseCode"], "references": "Course" }
]
```

- [ ] **Step 4: Write the rest of the manifest**

`id`: `d-i-11-why-normalize`, `order`: 11, `level`: `"intermediate"`, `track`/`kind`: `"design"`,
`estimatedMinutes`: 25, `topics`: `["normalization", "anomalies", "redundancy"]`.
`steps`: a `read` step anchored at `scenario`; a `sql` step prompting the learner to run the three
anomaly demonstrations; a `canvas` step prompting them to extract `Course`.
`startingModel`: one entity, `EnrolmentSheet`, with its columns — the learner starts from the awful table, not an empty canvas.

The narrative must cover, in this order:
1. **The update anomaly** — `UPDATE EnrolmentSheet SET StudentEmail = ... WHERE StudentId = 1` touches two rows for one fact. Show that missing one leaves the database holding two different emails for one student, and that nothing prevents it.
2. **The insert anomaly** — a new course with no students cannot be recorded at all, because `StudentId` is part of the primary key. This is the one the task fixes.
3. **The delete anomaly** — deleting Ayesha's only enrolment destroys the fact that `ST200` exists and what it is worth.
4. **Why the fix is a second table**, and the explicit statement that no normal form has been named yet: these are concrete data-loss bugs, and the normal forms are just names for the patterns that cause them.
5. **How this is graded** — the check confirms `Course` exists with `CourseCode` as its key, that `CourseTitle` and `Credits` are gone from `EnrolmentSheet`, and that the foreign key connects them. It does not and cannot verify that the learner understood *why*.

- [ ] **Step 5: Verify red then green**

Start the stack (`docker compose up -d`), then in the app open the module and press **Check** against the untouched starting model. Expected: FAIL — `Course` does not exist. Then apply `solution.sql` and press Check. Expected: every condition passes.

Both directions are required. A rule that cannot fail is not grading anything.

- [ ] **Step 6: Commit**

```bash
git add lessons/design/intermediate/d-i-11-why-normalize
git commit -m "Add the why-normalize module

Shows the update, insert and delete anomalies with real DML before naming a
single normal form, then fixes the insert anomaly with the smallest possible
decomposition.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Module 12 — 1NF: repeating groups

**Files:**
- Create: `lessons/design/intermediate/d-i-12-first-normal-form/manifest.json`
- Create: `lessons/design/intermediate/d-i-12-first-normal-form/seed.sql`
- Create: `lessons/design/intermediate/d-i-12-first-normal-form/solution.sql`

**Interfaces:**
- Consumes: the `EnrolmentSheet` shape from Task 1, *after* module 11's decomposition (no `CourseTitle`, no `Credits`, `Course` exists).
- Produces: `StudentPhone` and `StudentSkill` child tables.

**What this module argues:** `Phone1/Phone2/Phone3` and a comma-separated `Skills` column are the *same* mistake wearing two costumes. The numbered columns are obviously wrong; the CSV column looks tidy and is worse, because it cannot be indexed, joined, counted or constrained.

- [ ] **Step 1: Write `seed.sql`** — the module-11 end state:

```sql
DROP TABLE IF EXISTS EnrolmentSheet;
DROP TABLE IF EXISTS Course;

CREATE TABLE Course (
    CourseCode  nvarchar(12)  NOT NULL,
    CourseTitle nvarchar(120) NOT NULL,
    Credits     int           NOT NULL,
    CONSTRAINT PK_Course PRIMARY KEY (CourseCode)
);
INSERT INTO Course VALUES
 ('DB101','Database Fundamentals',15), ('ST200','Statistics',12);

CREATE TABLE EnrolmentSheet (
    StudentId        int            NOT NULL,
    StudentName      nvarchar(100)  NOT NULL,
    StudentEmail     nvarchar(200)  NOT NULL,
    Phone1           nvarchar(30)   NULL,
    Phone2           nvarchar(30)   NULL,
    Phone3           nvarchar(30)   NULL,
    Skills           nvarchar(400)  NULL,
    CourseCode       nvarchar(12)   NOT NULL,
    Term             nvarchar(12)   NOT NULL,
    InstructorName   nvarchar(100)  NOT NULL,
    InstructorOffice nvarchar(40)   NOT NULL,
    RoomCode         nvarchar(12)   NOT NULL,
    RoomBuilding     nvarchar(60)   NOT NULL,
    RoomCapacity     int            NOT NULL,
    Grade            nvarchar(2)    NULL,
    CONSTRAINT PK_EnrolmentSheet PRIMARY KEY (StudentId, CourseCode, Term),
    CONSTRAINT FK_EnrolmentSheet_Course FOREIGN KEY (CourseCode) REFERENCES Course (CourseCode)
);
INSERT INTO EnrolmentSheet VALUES
 (1,'Thandi Mokoena','thandi@example.ac.za','082 555 0101','021 555 0199',NULL,'SQL,Python','DB101','2026S1','Dr Naidoo','B-214','R101','Science Block',60,'A'),
 (2,'Sipho Dlamini','sipho@example.ac.za','083 555 0102',NULL,NULL,'Java','DB101','2026S1','Dr Naidoo','B-214','R101','Science Block',60,'B'),
 (3,'Ayesha Patel','ayesha@example.ac.za','084 555 0103','011 555 0177','072 555 0155','SQL,R,Excel','ST200','2026S1','Prof Botha','C-108','R205','Maths Block',40,'A'),
 (1,'Thandi Mokoena','thandi@example.ac.za','082 555 0101','021 555 0199',NULL,'SQL,Python','ST200','2026S1','Prof Botha','C-108','R205','Maths Block',40,'B');
```

- [ ] **Step 2: Write `solution.sql`**

```sql
DROP TABLE IF EXISTS StudentPhone;
CREATE TABLE StudentPhone (
    StudentId int          NOT NULL,
    Phone     nvarchar(30) NOT NULL,
    CONSTRAINT PK_StudentPhone PRIMARY KEY (StudentId, Phone)
);

DROP TABLE IF EXISTS StudentSkill;
CREATE TABLE StudentSkill (
    StudentId int          NOT NULL,
    Skill     nvarchar(60) NOT NULL,
    CONSTRAINT PK_StudentSkill PRIMARY KEY (StudentId, Skill)
);

ALTER TABLE EnrolmentSheet DROP COLUMN Phone1;
ALTER TABLE EnrolmentSheet DROP COLUMN Phone2;
ALTER TABLE EnrolmentSheet DROP COLUMN Phone3;
ALTER TABLE EnrolmentSheet DROP COLUMN Skills;
```

- [ ] **Step 3: `designConditions`**

```json
[
  { "type": "entityExists", "table": "StudentPhone" },
  { "type": "columnExists", "table": "StudentPhone", "column": "Phone" },
  { "type": "entityExists", "table": "StudentSkill" },
  { "type": "columnExists", "table": "StudentSkill", "column": "Skill" },
  { "type": "columnAbsent", "table": "EnrolmentSheet", "column": "Phone1" },
  { "type": "columnAbsent", "table": "EnrolmentSheet", "column": "Phone2" },
  { "type": "columnAbsent", "table": "EnrolmentSheet", "column": "Phone3" },
  { "type": "columnAbsent", "table": "EnrolmentSheet", "column": "Skills" }
]
```

- [ ] **Step 4: Manifest** — `id`: `d-i-12-first-normal-form`, `order`: 12, `estimatedMinutes`: 25, `topics`: `["normalization", "1NF", "repeating groups"]`.

The narrative must make these points:
1. **Why `Phone3` is a design bug, not a limit** — the fourth phone number has nowhere to go, and `WHERE Phone1 = x OR Phone2 = x OR Phone3 = x` is unindexable.
2. **Why the CSV column is not better.** Ask the learner to find every student with the SQL skill using `LIKE '%SQL%'` and notice it also matches a hypothetical `MySQL`. State plainly that a comma-separated column is a repeating group that has learned to hide.
3. **What "atomic" actually means** — not "small", but *"the database never has to split this value to answer a question."*
4. **The trade-off, honestly:** the decomposed form needs a join to reassemble, and for a value the application only ever displays whole (a postal address line, say) a single column can be right. The test is whether you ever query *into* the value.
5. **How this is graded** — the check confirms the two child tables exist with the right columns and that the four offending columns are gone. It cannot confirm the learner migrated the data correctly, so the module says so.

- [ ] **Step 5: Verify red then green** — Check against the seed must FAIL (no `StudentPhone`); after `solution.sql`, every condition must pass.

- [ ] **Step 6: Commit**

```bash
git add lessons/design/intermediate/d-i-12-first-normal-form
git commit -m "Add the 1NF module

Numbered columns and a comma-separated column are the same repeating group;
the second one just hides better.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Module 13 — 2NF: partial dependencies

**Files:**
- Create: `lessons/design/intermediate/d-i-13-second-normal-form/manifest.json`
- Create: `lessons/design/intermediate/d-i-13-second-normal-form/seed.sql`
- Create: `lessons/design/intermediate/d-i-13-second-normal-form/solution.sql`

**Interfaces:**
- Consumes: the module-12 end state (no repeating groups; `Course`, `StudentPhone`, `StudentSkill` exist).
- Produces: `Student` and `CourseOffering`. **`InstructorName` and `RoomCode` move to `CourseOffering`, keyed `(CourseCode, Term)` — not to `Course`.**

**What this module argues:** with a composite key, any attribute that depends on only *part* of it is in the wrong table. Three separate partial dependencies are present, and one of them (`(CourseCode, Term) → RoomCode, InstructorName`) depends on two of the three key columns, which is the case learners miss.

- [ ] **Step 1: Write `seed.sql`** — the module-12 end state: `EnrolmentSheet(StudentId, StudentName, StudentEmail, CourseCode, Term, InstructorName, InstructorOffice, RoomCode, RoomBuilding, RoomCapacity, Grade)` with PK `(StudentId, CourseCode, Term)`, plus `Course`, `StudentPhone` and `StudentSkill` populated as in Task 2.

- [ ] **Step 2: Write `solution.sql`**

```sql
DROP TABLE IF EXISTS Student;
CREATE TABLE Student (
    StudentId    int           NOT NULL,
    StudentName  nvarchar(100) NOT NULL,
    StudentEmail nvarchar(200) NOT NULL,
    CONSTRAINT PK_Student PRIMARY KEY (StudentId)
);
INSERT INTO Student SELECT DISTINCT StudentId, StudentName, StudentEmail FROM EnrolmentSheet;

DROP TABLE IF EXISTS CourseOffering;
CREATE TABLE CourseOffering (
    CourseCode       nvarchar(12)  NOT NULL,
    Term             nvarchar(12)  NOT NULL,
    InstructorName   nvarchar(100) NOT NULL,
    InstructorOffice nvarchar(40)  NOT NULL,
    RoomCode         nvarchar(12)  NOT NULL,
    RoomBuilding     nvarchar(60)  NOT NULL,
    RoomCapacity     int           NOT NULL,
    CONSTRAINT PK_CourseOffering PRIMARY KEY (CourseCode, Term),
    CONSTRAINT FK_CourseOffering_Course FOREIGN KEY (CourseCode) REFERENCES Course (CourseCode)
);
INSERT INTO CourseOffering
SELECT DISTINCT CourseCode, Term, InstructorName, InstructorOffice, RoomCode, RoomBuilding, RoomCapacity
FROM EnrolmentSheet;

ALTER TABLE EnrolmentSheet DROP COLUMN StudentName;
ALTER TABLE EnrolmentSheet DROP COLUMN StudentEmail;
ALTER TABLE EnrolmentSheet DROP COLUMN InstructorName;
ALTER TABLE EnrolmentSheet DROP COLUMN InstructorOffice;
ALTER TABLE EnrolmentSheet DROP COLUMN RoomCode;
ALTER TABLE EnrolmentSheet DROP COLUMN RoomBuilding;
ALTER TABLE EnrolmentSheet DROP COLUMN RoomCapacity;

ALTER TABLE EnrolmentSheet
    ADD CONSTRAINT FK_EnrolmentSheet_Student FOREIGN KEY (StudentId) REFERENCES Student (StudentId);
```

- [ ] **Step 3: `designConditions`**

```json
[
  { "type": "entityExists", "table": "Student" },
  { "type": "primaryKey", "table": "Student", "columns": ["StudentId"] },
  { "type": "columnExists", "table": "Student", "column": "StudentEmail" },
  { "type": "entityExists", "table": "CourseOffering" },
  { "type": "primaryKey", "table": "CourseOffering", "columns": ["CourseCode", "Term"] },
  { "type": "columnExists", "table": "CourseOffering", "column": "InstructorName" },
  { "type": "columnExists", "table": "CourseOffering", "column": "RoomCode" },
  { "type": "columnAbsent", "table": "EnrolmentSheet", "column": "StudentName" },
  { "type": "columnAbsent", "table": "EnrolmentSheet", "column": "StudentEmail" },
  { "type": "columnAbsent", "table": "EnrolmentSheet", "column": "InstructorName" },
  { "type": "columnAbsent", "table": "EnrolmentSheet", "column": "RoomCode" },
  { "type": "foreignKey", "table": "EnrolmentSheet", "columns": ["StudentId"], "references": "Student" }
]
```

- [ ] **Step 4: Manifest** — `id`: `d-i-13-second-normal-form`, `order`: 13, `estimatedMinutes`: 30, `topics`: `["normalization", "2NF", "partial dependencies", "composite keys"]`.

Narrative must cover:
1. **The definition, then the test.** 2NF: no non-key attribute depends on only part of a composite key. The practical test is to take each key column in turn and ask "does this attribute change when *only* this changes?"
2. **The three partial dependencies**, worked through one at a time, including the two-column case `(CourseCode, Term) → RoomCode`, which is the one that gets missed because it isn't a single column.
3. **Why the instructor is on the offering, not the course** — who teaches `DB101` is a fact about the *term*, not about the course forever. Note this decision explicitly; module 15 depends on it.
4. **2NF only bites on composite keys.** A table with a single-column key is already in 2NF, which is why surrogate keys can hide the problem rather than solve it — the dependency is still there, just no longer visible in the key.
5. **How this is graded** — structurally: the two tables, their keys, the moved columns gone, the FK present. The grader cannot see functional dependencies.

- [ ] **Step 5: Verify red then green.**

- [ ] **Step 6: Commit**

```bash
git add lessons/design/intermediate/d-i-13-second-normal-form
git commit -m "Add the 2NF module

Three partial dependencies, including the two-column case that learners miss.
The instructor lands on the offering rather than the course, which module 15
relies on.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Module 14 — 3NF: transitive dependencies

**Files:**
- Create: `lessons/design/intermediate/d-i-14-third-normal-form/manifest.json`
- Create: `lessons/design/intermediate/d-i-14-third-normal-form/seed.sql`
- Create: `lessons/design/intermediate/d-i-14-third-normal-form/solution.sql`

**Interfaces:**
- Consumes: the module-13 end state.
- Produces: `Instructor` and `Room`, both extracted from `CourseOffering`.

**What this module argues:** both remaining problems are inside `CourseOffering`, and both have the same shape — a non-key attribute determining another non-key attribute.

- [ ] **Step 1: Write `seed.sql`** — the module-13 end state: `Student`, `Course`, `StudentPhone`, `StudentSkill`, `CourseOffering` (with instructor and room columns still inline), and `EnrolmentSheet(StudentId, CourseCode, Term, Grade)`.

- [ ] **Step 2: Write `solution.sql`**

```sql
DROP TABLE IF EXISTS Instructor;
CREATE TABLE Instructor (
    InstructorName   nvarchar(100) NOT NULL,
    InstructorOffice nvarchar(40)  NOT NULL,
    CONSTRAINT PK_Instructor PRIMARY KEY (InstructorName)
);
INSERT INTO Instructor SELECT DISTINCT InstructorName, InstructorOffice FROM CourseOffering;

DROP TABLE IF EXISTS Room;
CREATE TABLE Room (
    RoomCode     nvarchar(12) NOT NULL,
    RoomBuilding nvarchar(60) NOT NULL,
    RoomCapacity int          NOT NULL,
    CONSTRAINT PK_Room PRIMARY KEY (RoomCode)
);
INSERT INTO Room SELECT DISTINCT RoomCode, RoomBuilding, RoomCapacity FROM CourseOffering;

ALTER TABLE CourseOffering DROP COLUMN InstructorOffice;
ALTER TABLE CourseOffering DROP COLUMN RoomBuilding;
ALTER TABLE CourseOffering DROP COLUMN RoomCapacity;

ALTER TABLE CourseOffering
    ADD CONSTRAINT FK_CourseOffering_Instructor
    FOREIGN KEY (InstructorName) REFERENCES Instructor (InstructorName);
ALTER TABLE CourseOffering
    ADD CONSTRAINT FK_CourseOffering_Room
    FOREIGN KEY (RoomCode) REFERENCES Room (RoomCode);
```

- [ ] **Step 3: `designConditions`**

```json
[
  { "type": "entityExists", "table": "Instructor" },
  { "type": "primaryKey", "table": "Instructor", "columns": ["InstructorName"] },
  { "type": "columnExists", "table": "Instructor", "column": "InstructorOffice" },
  { "type": "entityExists", "table": "Room" },
  { "type": "primaryKey", "table": "Room", "columns": ["RoomCode"] },
  { "type": "columnExists", "table": "Room", "column": "RoomCapacity" },
  { "type": "columnAbsent", "table": "CourseOffering", "column": "InstructorOffice" },
  { "type": "columnAbsent", "table": "CourseOffering", "column": "RoomBuilding" },
  { "type": "columnAbsent", "table": "CourseOffering", "column": "RoomCapacity" },
  { "type": "foreignKey", "table": "CourseOffering", "columns": ["InstructorName"], "references": "Instructor" },
  { "type": "foreignKey", "table": "CourseOffering", "columns": ["RoomCode"], "references": "Room" }
]
```

- [ ] **Step 4: Manifest** — `id`: `d-i-14-third-normal-form`, `order`: 14, `estimatedMinutes`: 30, `topics`: `["normalization", "3NF", "transitive dependencies"]`.

Narrative must cover:
1. **The shape:** key → non-key → non-key. `(CourseCode, Term) → RoomCode → RoomBuilding`. The building is a fact about the *room*, not about the offering, and it is stored once per offering that happens to use that room.
2. **"A fact about a fact"** as the recognition heuristic, applied to both cases.
3. **The mnemonic, and its limits.** *"The key, the whole key, and nothing but the key"* covers 1NF/2NF/3NF neatly — and stops working at BCNF, which module 15 opens with. Say that here, so the next module lands.
4. **Why `RoomCapacity` is a good example** — it is genuinely a property of the room, and someone will be tempted to keep a copy on the offering "for reporting". Note that module 17 will do exactly that, on purpose, and measure what it costs.
5. **How this is graded** — structurally, as before.

- [ ] **Step 5: Verify red then green.**

- [ ] **Step 6: Commit**

```bash
git add lessons/design/intermediate/d-i-14-third-normal-form
git commit -m "Add the 3NF module

Both remaining problems live in CourseOffering and share one shape: a non-key
attribute determining another. Ends by retiring the 'nothing but the key'
mnemonic, which module 15 breaks.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Module 15 — BCNF: when 3NF isn't enough

**Files:**
- Create: `lessons/design/intermediate/d-i-15-bcnf/manifest.json`
- Create: `lessons/design/intermediate/d-i-15-bcnf/seed.sql`
- Create: `lessons/design/intermediate/d-i-15-bcnf/solution.sql`

**Interfaces:**
- Consumes: the module-14 end state.
- Produces: `InstructorCourse` and `StudentInstructor`, replacing `StudentCourseInstructor`.

**The theory, which must be got exactly right.** The department now records *which* instructor taught *which* student, under two rules: a course may be taught by several instructors, and **each instructor teaches only one course**. That gives `StudentCourseInstructor(StudentId, CourseCode, InstructorName)` with:

- FDs: `(StudentId, CourseCode) → InstructorName` and `InstructorName → CourseCode`
- Candidate keys: `{StudentId, CourseCode}` and `{StudentId, InstructorName}` — they overlap on `StudentId`
- **It is in 3NF**, because the only offending determinant's dependent (`CourseCode`) is a *prime* attribute — part of a candidate key. 3NF explicitly permits this.
- **It violates BCNF**, because `InstructorName` is not a superkey.

This is the standard `R(A,B,C)` case: candidate keys `{A,B}` and `{A,C}` with `B → C`.

- [ ] **Step 1: Write `seed.sql`** — the module-14 end state, plus:

```sql
DROP TABLE IF EXISTS StudentCourseInstructor;
CREATE TABLE StudentCourseInstructor (
    StudentId      int           NOT NULL,
    CourseCode     nvarchar(12)  NOT NULL,
    InstructorName nvarchar(100) NOT NULL,
    CONSTRAINT PK_StudentCourseInstructor PRIMARY KEY (StudentId, CourseCode),
    CONSTRAINT UQ_StudentCourseInstructor UNIQUE (StudentId, InstructorName)
);
INSERT INTO StudentCourseInstructor VALUES
 (1,'DB101','Dr Naidoo'), (2,'DB101','Dr Naidoo'),
 (1,'ST200','Prof Botha'), (3,'ST200','Prof Botha');
```

The `UNIQUE` constraint is not decoration — it is the second candidate key, and it makes the overlapping-key structure visible in the schema rather than only in the prose.

- [ ] **Step 2: Write `solution.sql`**

```sql
DROP TABLE IF EXISTS InstructorCourse;
CREATE TABLE InstructorCourse (
    InstructorName nvarchar(100) NOT NULL,
    CourseCode     nvarchar(12)  NOT NULL,
    CONSTRAINT PK_InstructorCourse PRIMARY KEY (InstructorName),
    CONSTRAINT FK_InstructorCourse_Course FOREIGN KEY (CourseCode) REFERENCES Course (CourseCode)
);
INSERT INTO InstructorCourse SELECT DISTINCT InstructorName, CourseCode FROM StudentCourseInstructor;

DROP TABLE IF EXISTS StudentInstructor;
CREATE TABLE StudentInstructor (
    StudentId      int           NOT NULL,
    InstructorName nvarchar(100) NOT NULL,
    CONSTRAINT PK_StudentInstructor PRIMARY KEY (StudentId, InstructorName),
    CONSTRAINT FK_StudentInstructor_Instructor FOREIGN KEY (InstructorName) REFERENCES InstructorCourse (InstructorName)
);
INSERT INTO StudentInstructor SELECT DISTINCT StudentId, InstructorName FROM StudentCourseInstructor;

DROP TABLE StudentCourseInstructor;
```

- [ ] **Step 3: `designConditions`**

```json
[
  { "type": "entityExists", "table": "InstructorCourse" },
  { "type": "primaryKey", "table": "InstructorCourse", "columns": ["InstructorName"] },
  { "type": "columnExists", "table": "InstructorCourse", "column": "CourseCode" },
  { "type": "entityExists", "table": "StudentInstructor" },
  { "type": "primaryKey", "table": "StudentInstructor", "columns": ["StudentId", "InstructorName"] },
  { "type": "columnAbsent", "table": "StudentInstructor", "column": "CourseCode" },
  { "type": "foreignKey", "table": "StudentInstructor", "columns": ["InstructorName"], "references": "InstructorCourse" }
]
```

Note the `columnAbsent` on `StudentInstructor.CourseCode`: without it, a learner could create both tables and leave the course code duplicated on the student side, which is the redundancy BCNF exists to remove.

- [ ] **Step 4: Manifest** — `id`: `d-i-15-bcnf`, `order`: 15, `estimatedMinutes`: 35, `topics`: `["normalization", "BCNF", "candidate keys", "dependency preservation"]`.

Narrative must cover, and must not overclaim:
1. **The two rules**, stated plainly, and the observation that they make `InstructorName` a determinant of `CourseCode`.
2. **Both candidate keys**, and that they overlap on `StudentId`. BCNF violations require overlapping candidate keys — a table with one candidate key in 3NF is already in BCNF. State this, because it tells the learner when they can stop looking.
3. **Why 3NF passes and BCNF fails.** 3NF forgives a non-superkey determinant when what it determines is a *prime* attribute. `CourseCode` is prime. BCNF removes that exemption: every determinant must be a superkey. **This is the whole difference between the two forms** and is where the module earns its place.
4. **The redundancy it actually removes** — "Dr Naidoo teaches DB101" is stored once per enrolled student, so two rows can disagree about which course an instructor teaches.
5. **The cost, stated honestly.** The decomposition is lossless but **not dependency-preserving**: `(StudentId, CourseCode) → InstructorName` can no longer be enforced by either table alone, and would need a trigger or an application check. **BCNF is the one normal form that can cost you a constraint. Do not present it as strictly better than 3NF** — a real design sometimes stops at 3NF for exactly this reason, and that is a legitimate engineering decision rather than laziness.
6. **How this is graded** — the check confirms the two tables, their keys, that `CourseCode` is gone from the student side, and the FK. It cannot verify that the two rules hold in the learner's head, and it cannot check dependency preservation at all.

- [ ] **Step 5: Verify red then green.** Also confirm the seed's `UNIQUE (StudentId, InstructorName)` constraint is read back correctly by `SchemaReader` — it is the second candidate key and the module's narrative points at it.

- [ ] **Step 6: Commit**

```bash
git add lessons/design/intermediate/d-i-15-bcnf
git commit -m "Add the BCNF module

The overlapping-candidate-key case 3NF permits: 3NF forgives a non-superkey
determinant when what it determines is prime, and BCNF does not.

States the cost rather than selling the form - the decomposition is lossless
but not dependency-preserving, so stopping at 3NF is a legitimate decision.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Register the five modules

**Files:**
- Modify: `web/src/design/roadmap.ts` (the `intermediate` block, entries `n: 11` through `n: 15`)

**Interfaces:**
- Consumes: the five module `id` values created in Tasks 1–5.
- Produces: clickable roadmap entries; the level's counter changes from `0/0` to `0/5`.

- [ ] **Step 1: Add the `id` field to entries 11–15**

Each intermediate entry currently has `n`, `title` and `blurb` but no `id`, which is what makes it render as "coming soon" rather than a link. Add exactly:

```ts
{ n: 11, id: "d-i-11-why-normalize", ... }
{ n: 12, id: "d-i-12-first-normal-form", ... }
{ n: 13, id: "d-i-13-second-normal-form", ... }
{ n: 14, id: "d-i-14-third-normal-form", ... }
{ n: 15, id: "d-i-15-bcnf", ... }
```

Leave the existing `title` and `blurb` values on each entry unchanged, and leave entries 16–19 without an `id`.

- [ ] **Step 2: Build**

Run: `cd web && npm run build`
Expected: no TypeScript errors.

- [ ] **Step 3: Verify in a real browser**

Load `/design` and **hard-reload with cache disabled** — a plain reload serves a stale bundle.

Confirm: the Intermediate section shows `0/5`; entries 11–15 are links and open their modules; entries 16–19 still read "coming soon"; the console has no errors.

- [ ] **Step 4: Commit**

```bash
git add web/src/design/roadmap.ts
git commit -m "Register the five normalization modules on the roadmap

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Notes for the implementer

**The seed of each module is the solution of the one before it.** That is what makes this a spine rather than five exercises. If you change a column name in Task 2, Tasks 3–5 must follow. Check the FD table at the top of this plan before renaming anything.

**`Instructor` and `InstructorCourse` coexist deliberately, and the narrative must say why.**
Module 14 creates `Instructor(InstructorName, InstructorOffice)` — where an instructor's office
is. Module 15 creates `InstructorCourse(InstructorName, CourseCode)` — which course they teach.
A reader will reasonably ask why these are not one table, and the answer is that they could be:
the split falls out of the modules arriving in this order, not from a rule. Say that plainly
rather than leaving the learner to assume a principle that isn't there. If merging them reads
better once both modules are written, merge them and adjust module 15's conditions to match —
but decide it deliberately.

**Do not add a `columnAbsent` rule without a matching `entityExists`.** `columnAbsent` fails when the table is missing — deliberately — so a module that only asserts absence would be unsatisfiable if the learner has not built the table yet. Every task above pairs them.

**Content is verified before writing, not after.** The FD analysis in this plan was checked against the standard characterisation of 3NF-but-not-BCNF. If you find yourself unsure whether something is a 2NF or a 3NF violation, work out the candidate keys first — the answer follows mechanically from which attributes are prime.

**What this increment does not do:** modules 16 (4NF/5NF), 17 (denormalizing), 18 (naming) and 19 (the capstone) are increment 3.

**The lesson catalog is loaded once at process start.** The `lessons` directory is
bind-mounted into the API container, so edits appear on disk immediately — but
`LessonCatalog` reads them into memory at startup and does not watch the
directory. A new module 404s until `docker compose restart api`. Do that before
concluding a manifest is malformed.

## Found while executing this plan

Two things the plan assumed were in place turned out not to be, and both were
fixed here rather than deferred:

- **The design track had nowhere to run a query.** Every narrative says "run
  this" and shows a `SELECT`, but `ResultsPanel` was mounted only by the
  performance track; a query pasted into the DDL box ran and had its rows
  discarded. Beginner module 1 shipped in that state. There is now a scratch
  query box, deliberately separate from the DDL pane — the DDL pane is the
  graded artefact and Check rebuilds the schema from it, while a scratch run
  executes against the schema as it stands and resets nothing. That separation
  is what makes module 11's anomaly demonstrations possible at all.
- **Markdown tables did not render.** `ReactMarkdown` was mounted with no
  plugins, so GFM tables came out as literal pipe characters. Fixed with
  `remark-gfm` plus styling for `.markdown-body` tables, which had none. This
  passed a build and a type-check and was only visible on the rendered page —
  the DOM contained the text throughout.
