# Intermediate Increment 1 — Machinery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the `columnAbsent` grading rule and a step bar that renders the `steps` data every module already authors, so the Intermediate normalization modules have the machinery they need.

**Architecture:** `columnAbsent` is a new arm in `DesignEvaluator`'s rule switch — a pure function over `SchemaDto`, added test-first in the repo's first test project. `<StepBar>` is a presentational React component rendering `module.steps` above the existing panes; it holds one piece of local state (which step is selected) and focuses the matching pane on click. Nothing persists, nothing locks.

**Tech Stack:** .NET 10 / ASP.NET Core / xUnit; React 19 + TypeScript + Vite; plain CSS in `web/src/styles.css`.

## Global Constraints

- **Grading reads the real database, never the canvas.** Rules take `SchemaDto` — the schema read back from the engine — and nothing else.
- **Normal forms are graded structurally, never semantically.** A rule asserts a schema fact. It never claims to have verified the learner's reasoning.
- **Identifiers reaching SQL are allowlisted, never escaped.** This increment adds no SQL generation, so it inherits this constraint without exercising it.
- **Target framework is `net10.0`** with `<Nullable>enable</Nullable>`.
- **Rule type strings are camelCase** and match the manifest verbatim: the new one is exactly `columnAbsent`.
- **Comments explain *why*, not *what*** — matching the existing house style in `DesignEvaluator.cs`.
- **The repo has no existing tests.** Task 1 creates the first test project; there is no prior convention to match, so follow the structure given here exactly.

---

### Task 1: Test project and the `columnAbsent` rule

**Files:**
- Create: `api/SqlPerf.Api.Tests/SqlPerf.Api.Tests.csproj`
- Create: `api/SqlPerf.Api.Tests/DesignEvaluatorTests.cs`
- Modify: `api/SqlPerf.Api/Services/DesignEvaluator.cs` (add switch arm at line ~40, add method near `ColumnExists`)
- Modify: `.github/workflows/ci.yml` (add a `dotnet test` step to the `build-api` job)

**Interfaces:**
- Consumes: `DesignEvaluator.Evaluate(IReadOnlyList<RuleSpec>, SchemaDto)` → `EvaluationDto`; `RuleSpec` (fields `Type`, `Table`, `Column`); `SchemaDto(string Schema, bool Seeded, List<SchemaTableDto> Tables)`; `SchemaTableDto(string Name, long RowCount, List<SchemaColumnDto> Columns, List<SchemaIndexDto> Indexes, List<SchemaForeignKeyDto> ForeignKeys, bool IsJunction, List<SchemaCheckDto> Checks)`; `SchemaColumnDto(string Name, string DataType, bool Nullable, bool IsIdentity, bool InPrimaryKey, string? DefaultDefinition)`; `EvaluationDto(bool Passed, List<ConditionResultDto> Conditions)`; `ConditionResultDto(string Type, string Label, bool Passed, string Detail)`.
- Produces: rule type `"columnAbsent"`, consumed by every Intermediate module manifest in increments 2 and 3.

**The behaviour that matters:** when the *table* is missing, the rule must **fail**, not pass. "CourseTitle is absent from Enrolment" is vacuously true if `Enrolment` does not exist — and a rule that passes then would let a learner score points by deleting the table instead of decomposing it. That is the whole reason this task is test-first.

- [ ] **Step 1: Create the test project**

```bash
cd X:/Playground/sql-database-design
dotnet new xunit -o api/SqlPerf.Api.Tests -f net10.0
dotnet add api/SqlPerf.Api.Tests/SqlPerf.Api.Tests.csproj reference api/SqlPerf.Api/SqlPerf.Api.csproj
```

- [ ] **Step 2: Write the failing tests**

Replace the whole contents of `api/SqlPerf.Api.Tests/DesignEvaluatorTests.cs`:

```csharp
using SqlPerf.Api.Models;
using SqlPerf.Api.Services;
using Xunit;

namespace SqlPerf.Api.Tests;

public class DesignEvaluatorTests
{
    // Builds a schema with one table and the named columns. Everything the rule
    // does not look at is given a harmless default, so a test reads as the one
    // fact it is about.
    private static SchemaDto SchemaWith(string table, params string[] columns) =>
        new("dbo", true, new List<SchemaTableDto>
        {
            new(table, 0,
                columns.Select(c => new SchemaColumnDto(c, "int", true, false, false, null)).ToList(),
                new List<SchemaIndexDto>(),
                new List<SchemaForeignKeyDto>(),
                false,
                new List<SchemaCheckDto>())
        });

    private static RuleSpec Absent(string table, string column) =>
        new() { Type = "columnAbsent", Table = table, Column = column };

    [Fact]
    public void ColumnAbsent_passes_when_the_column_was_moved_out()
    {
        var schema = SchemaWith("Enrolment", "StudentId", "CourseCode");

        var result = DesignEvaluator.Evaluate(new[] { Absent("Enrolment", "CourseTitle") }, schema);

        Assert.True(result.Passed);
    }

    [Fact]
    public void ColumnAbsent_fails_when_the_redundant_column_is_still_there()
    {
        var schema = SchemaWith("Enrolment", "StudentId", "CourseCode", "CourseTitle");

        var result = DesignEvaluator.Evaluate(new[] { Absent("Enrolment", "CourseTitle") }, schema);

        Assert.False(result.Passed);
    }

    [Fact]
    public void ColumnAbsent_is_case_insensitive_like_SQL_Server()
    {
        var schema = SchemaWith("Enrolment", "coursetitle");

        var result = DesignEvaluator.Evaluate(new[] { Absent("Enrolment", "CourseTitle") }, schema);

        Assert.False(result.Passed);
    }

    // The load-bearing case. Deleting the table must not be a way to pass a
    // rule that asks for a column to have been moved out of it.
    [Fact]
    public void ColumnAbsent_fails_when_the_table_itself_is_missing()
    {
        var schema = SchemaWith("SomethingElse", "StudentId");

        var result = DesignEvaluator.Evaluate(new[] { Absent("Enrolment", "CourseTitle") }, schema);

        Assert.False(result.Passed);
        Assert.Contains("no table", result.Conditions[0].Detail);
    }
}
```

- [ ] **Step 3: Run the tests and confirm they fail for the right reason**

Run: `dotnet test api/SqlPerf.Api.Tests/SqlPerf.Api.Tests.csproj`

Expected: **exactly two tests fail** —
`ColumnAbsent_passes_when_the_column_was_moved_out` and
`ColumnAbsent_fails_when_the_table_itself_is_missing`.

`columnAbsent` is not implemented, so `DesignEvaluator` hits its `_ =>` fallback and returns
`("Unknown rule 'columnAbsent'", false, "unsupported")` — everything fails. That means the two
negative tests (`..._still_there` and `..._case_insensitive`) **pass for the wrong reason**, and
they only become meaningful once the rule exists. The table-missing test still fails because it
asserts on the detail string (`"unsupported"` does not contain `"no table"`), which is exactly
why that assertion is there.

Confirm you see 2 failed / 2 passed before implementing. If all four pass, the rule name is
misspelled somewhere and the fallback is not being hit.

- [ ] **Step 4: Add the switch arm**

In `api/SqlPerf.Api/Services/DesignEvaluator.cs`, in the `rule.Type switch` block, add the new arm directly after the `"columnExists"` line:

```csharp
                "columnAbsent" => ColumnAbsent(rule, schema),
```

- [ ] **Step 5: Implement the rule**

In the same file, directly after the `ColumnExists` method:

```csharp
    // The inverse of ColumnExists, and the rule normalization is graded on: a
    // decomposition is only real if the redundant column left the table it did
    // not belong in.
    //
    // A missing table fails rather than passes. "CourseTitle is absent from
    // Enrolment" is vacuously true when there is no Enrolment, and treating
    // that as a pass would reward deleting the table instead of decomposing it.
    private static (string, bool, string) ColumnAbsent(RuleSpec r, SchemaDto s)
    {
        var label = $"{r.Table}.{r.Column} no longer exists";
        var t = Table(s, r.Table);
        if (t is null) return (label, false, $"no table {r.Table}");

        var c = t.Columns.FirstOrDefault(x => Eq(x.Name, r.Column));
        return c is null
            ? (label, true, "moved out")
            : (label, false, $"still present as {c.DataType}");
    }
```

- [ ] **Step 6: Run the tests and confirm they pass**

Run: `dotnet test api/SqlPerf.Api.Tests/SqlPerf.Api.Tests.csproj`

Expected: PASS, 4 of 4.

- [ ] **Step 7: Add the test step to CI**

In `.github/workflows/ci.yml`, in the `build-api` job, immediately after the existing `dotnet build` step, add:

```yaml
      - name: Test
        run: dotnet test api/SqlPerf.Api.Tests/SqlPerf.Api.Tests.csproj --configuration Release --verbosity normal
```

- [ ] **Step 8: Commit**

```bash
git add api/SqlPerf.Api.Tests api/SqlPerf.Api/Services/DesignEvaluator.cs .github/workflows/ci.yml
git commit -m "Add the columnAbsent grading rule

Every existing rule asserts that something exists. Normalization needs the
opposite: a decomposition is only real if the redundant column left the table
it did not belong in.

A missing table fails rather than passes, so deleting a table is not a way to
score the rule that asks you to decompose it. That case is why this arrived
with the repo's first test project.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: The step bar

**Files:**
- Create: `web/src/design/StepBar.tsx`
- Modify: `web/src/routes/ModuleRoute.tsx` (import; render between `.lesson-head` and `.module-body`, around line 178)
- Modify: `web/src/styles.css` (append the block below near the `.module-body` rules, line ~509)

**Interfaces:**
- Consumes: `ModuleStep` from `web/src/design/types.ts` — `{ kind: "read" | "canvas" | "sql"; prompt?: string; anchor?: string }`; `module.steps` on the module detail object already fetched by `ModuleRoute`.
- Produces: `<StepBar steps={...} />`. Self-contained; nothing later depends on its internals.

**Why this exists:** `ModuleStep` is typed, authored in all ten Beginner manifests, and shipped over the wire in `ModuleDetailDto` — and nothing renders it. This task consumes data that already exists, so it improves all ten shipped modules on merge.

Behaviour is deliberately passive: clicking a step selects it and scrolls the matching pane into view. Nothing locks, nothing gates, and no state persists. `narrative`, `canvas` and `sql` are the three pane class names already present in `ModuleRoute`.

- [ ] **Step 1: Create the component**

Create `web/src/design/StepBar.tsx`:

```tsx
import { useState } from "react";
import type { ModuleStep } from "./types";

// What each step kind is called for a learner, and which pane it belongs to.
// The pane class names are the ones ModuleRoute already renders.
const STEP_META: Record<ModuleStep["kind"], { label: string; pane: string }> = {
  read: { label: "Read", pane: "narrative" },
  canvas: { label: "Model", pane: "canvas" },
  sql: { label: "Run", pane: "sql" },
};

/**
 * A passive progress map over a module's steps.
 *
 * Passive is the point: it shows where you are and lets you jump, but nothing
 * unlocks and nothing is recorded. A gated sequence would need per-step
 * completion state and an escape hatch, and would fight the learner who
 * already knows the material.
 */
export function StepBar({ steps }: { steps: ModuleStep[] }) {
  const [current, setCurrent] = useState(0);
  if (steps.length === 0) return null;

  return (
    <ol className="stepbar" aria-label="Module steps">
      {steps.map((step, i) => {
        const meta = STEP_META[step.kind];
        return (
          <li key={i}>
            <button
              type="button"
              className={`stepbar-step ${i === current ? "is-current" : ""}`}
              aria-current={i === current ? "step" : undefined}
              onClick={() => {
                setCurrent(i);
                document
                  .querySelector(`.module-body > .${meta.pane}`)
                  ?.scrollIntoView({ behavior: "smooth", block: "nearest" });
              }}
            >
              <span className="stepbar-n">{i + 1}</span>
              <span className="stepbar-label">{meta.label}</span>
              {step.prompt && <span className="stepbar-prompt">{step.prompt}</span>}
            </button>
          </li>
        );
      })}
    </ol>
  );
}
```

- [ ] **Step 2: Render it in ModuleRoute**

In `web/src/routes/ModuleRoute.tsx`, add the import beside the other `./design` imports:

```tsx
import { StepBar } from "../design/StepBar";
```

Then, between the closing `</div>` of `.lesson-head` and the opening `<div className="module-body"`, add:

```tsx
      <StepBar steps={module.steps} />
```

- [ ] **Step 3: Add the styles**

Append to `web/src/styles.css`:

```css
/* Passive progress map over a module's steps. Horizontal, scrollable on
   narrow viewports rather than wrapping, so the page body never scrolls
   sideways. */
.stepbar {
  display: flex;
  gap: 8px;
  margin: 0;
  padding: 8px 18px;
  list-style: none;
  overflow-x: auto;
  border-bottom: 1px solid var(--border);
}
.stepbar-step {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 12px;
  border: 1px solid var(--border);
  border-radius: 999px;
  background: transparent;
  color: var(--fg);
  font: inherit;
  font-size: 13px;
  white-space: nowrap;
  cursor: pointer;
}
.stepbar-step:hover { border-color: var(--accent); }
.stepbar-step.is-current { border-color: var(--accent); color: var(--accent); }
.stepbar-n {
  display: inline-grid;
  place-items: center;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: var(--border);
  font-size: 11px;
}
.stepbar-step.is-current .stepbar-n { background: var(--accent); color: var(--bg); }
.stepbar-label { font-weight: 600; }
.stepbar-prompt { opacity: 0.7; }
```

- [ ] **Step 4: Build**

Run: `cd web && npm run build`
Expected: builds with no TypeScript errors.

- [ ] **Step 5: Verify in a real browser**

A green build proves the types line up and nothing more. Start the app, then load a **Beginner** module — every one of them already authors `steps`, so the bar must appear without any content change:

Open `http://localhost:5173/design/modules/d-b-10-capstone-order-entry` and **hard-reload with cache disabled**, or a stale bundle will have you debugging a fix that already worked.

Confirm all of:
- Three steps render: `1 Read`, `2 Model`, `3 Run`.
- Clicking a step highlights it and scrolls the matching pane into view.
- The console has no errors or warnings.
- The page body does not scroll horizontally at a narrow window width.

- [ ] **Step 6: Commit**

```bash
git add web/src/design/StepBar.tsx web/src/routes/ModuleRoute.tsx web/src/styles.css
git commit -m "Render module steps as a passive progress map

ModuleStep was typed, authored in all ten Beginner manifests and shipped in
ModuleDetailDto, but nothing rendered it. This is the stepper the roadmap
advertises for the Intermediate level, and it improves the ten shipped
modules on merge because they already carry the data.

Passive by design: it shows where you are and lets you jump, but nothing
unlocks and no state persists.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Ship it

**Files:**
- Modify: none — this task is verification and merge.

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: `columnAbsent` and `<StepBar>` live in production, ready for increment 2.

- [ ] **Step 1: Full build and test**

```bash
dotnet test api/SqlPerf.Api.Tests/SqlPerf.Api.Tests.csproj
cd web && npm run build
```

Expected: 4 of 4 tests pass; web builds clean.

- [ ] **Step 2: Confirm no existing rule regressed**

The switch arm was inserted, not rewritten, but confirm a shipped module still grades correctly end to end. Run a Beginner module's Check against its solution and confirm it still passes every condition.

- [ ] **Step 3: Open the PR**

```bash
git push -u origin feat/intermediate-normalization
gh pr create --base main --title "Intermediate increment 1: columnAbsent and the step bar"
```

- [ ] **Step 4: Confirm CI is green, including the new test step**

```bash
gh pr view --json statusCheckRollup -q '.statusCheckRollup[] | "\(.name): \(.conclusion // .state)"'
```

Expected: `build-api` and `build-web` SUCCESS; `deploy-api`/`deploy-web` SKIPPED on the PR.

- [ ] **Step 5: Merge, then verify production**

Merging to `main` auto-deploys. After merging, confirm the deploy actually ran and the site actually changed — a green build says nothing about production.

**Blocker to clear first:** Azure OIDC is currently broken. The 2026-08-04 repo rename (`seek-and-destroy-sql` → `ccs-sql-academy`) invalidated the Entra federated identity credentials, which pin their subject to the repo path, so `deploy-api` fails with `AADSTS700213`. **This increment changes `DesignEvaluator`, so it needs a working API deploy.** Both credentials on app registration `997de621-49ce-4294-9a04-9cbab066bdf2` must be updated with `az ad app federated-credential update` before merging, or the rule will never reach production.

---

## Notes for the implementer

**Why `columnAbsent` is not just "nice to have":** it is the only rule in the system that can detect a *failed* decomposition. Every other rule is satisfied by adding things. A learner who creates `Course` correctly but leaves `CourseTitle` sitting in `Enrolment` has done exactly the wrong thing, and without this rule the grader congratulates them.

**Why the step bar is in this increment at all:** the roadmap promises a "Normalization stepper" for Intermediate. Rather than build a bespoke widget, this renders the `steps` field that already exists and is already authored everywhere. If a later module genuinely needs a step kind beyond `read`/`canvas`/`sql`, extend the `ModuleStep` union — do not add a parallel mechanism.

**What this increment deliberately does not do:** no manifest changes, no API contract changes, no new step kinds, and no content. Modules 11–19 are increments 2 and 3.
