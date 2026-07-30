# Run Selected Statement — Design

**Date:** 2026-07-30
**Status:** Approved, ready for implementation planning

## Problem

The SQL editor runs everything in the buffer. A lesson solution is often two or
more statements — typically `CREATE INDEX …;` followed by the `SELECT` being
tuned — and there is no way to re-run just one of them. To re-check the `SELECT`
after the index exists you must delete the other statements, run, then type them
back.

## Goal

Select some SQL, right-click, and choose **Run Selection** to execute only that
text, seeing its results, statistics and execution plan.

## Non-goals

- Detecting the statement under the cursor. Rejected: it means splitting T-SQL on
  semicolons, which is wrong inside string literals, comments and `BEGIN … END`
  blocks. You select the text you want.
- Changing what `Ctrl+Enter` does. It stays the graded full run.
- Any change to concurrency lessons, which use a different editor and the
  separate `/run-concurrency` endpoint.

## Decisions

### A selection run is never graded

This is the load-bearing decision. `POST /api/lessons/{id}/run`
(`api/SqlPerf.Api/Program.cs:100`) evaluates whatever SQL it receives against the
lesson's pass conditions and calls `ProgressStore.RecordSolveAsync` when it
passes. Grading a fragment through that path is both meaningless and unsafe:

- **False passes.** Per-table `maxLogicalReads` grading depends on the graded
  `SELECT` running *last in the batch* — that is how an index build's scan cost
  is excluded (`ParseStats` keeps only the last `Table 'X'` STATISTICS IO line per
  table). Re-running only the `SELECT` after an earlier full run already created
  the index would pass without the submission containing the index at all.
- **False fails.** `resultUnchanged` compares against a baseline captured from the
  lesson's `startingQuery`. A fragment returning different rows fails for reasons
  that say nothing about the user's solution.

The project has already been bitten once by lessons being wrongly marked solved,
so a selection run must not be able to write progress.

### The guarantee lives on the server

Considered and rejected: have the frontend POST to `/run` and ignore the
evaluation in the UI. The server would still call `RecordSolveAsync`, so a lesson
would be silently marked solved. A UI-side guarantee is not a guarantee.

Also considered: a separate `/api/lessons/{id}/scratch` endpoint. Cleaner
separation, and structurally incapable of touching progress, but it duplicates
the run plumbing and the two would drift.

Chosen: an optional flag on the existing request, branching inside the one
handler. Smallest change that puts the guarantee server-side.

## Design

### 1. API

`RunRequest` (`api/SqlPerf.Api/Models/Contracts.cs:103`, currently
`public sealed record RunRequest(string Sql);`) gains a defaulted flag:

```csharp
public sealed record RunRequest(string Sql, bool Graded = true);
```

The default preserves today's behaviour for every existing caller.

In the `/api/lessons/{id}/run` handler, when `Graded` is false:

- Execute via `SqlExecutor.RunAsync` exactly as now. Plan and statistics capture
  need no special handling: `RunAsync` prepends
  `SET STATISTICS IO ON; SET STATISTICS TIME ON; SET STATISTICS XML ON;` to
  whatever SQL it is given, so a selection yields the same artifacts as a full run.
- Skip `GetBaselineAsync` — it is only an input to grading, and skipping it avoids
  a needless query.
- Skip `Evaluator.EvaluateQuery`; return `Evaluation = null`.
- Return current progress via `ProgressStore.GetAsync`, never `RecordSolveAsync`.

`RunAsync` calls `EnsureSeededAsync` internally, which is idempotent, so a scratch
run neither reseeds nor otherwise disturbs lesson state.

The error path is unchanged: a failed execution already returns before any
grading happens, so a syntax error in a selection reports exactly as it does today.

### 2. API client

`api.run` (`web/src/api.ts:28`) takes a third argument:

```ts
run: (id: string, sql: string, graded = true) => …
  body: JSON.stringify({ sql, graded }),
```

Defaulting to `true` keeps the existing call site untouched.

### 3. Editor

`LessonView.tsx:188` renders `<Editor>` without holding a reference to the
instance. Add an `onMount` handler that keeps the instance in a ref and registers
one action:

```ts
editor.addAction({
  id: "sqlperf.runSelection",
  label: "Run Selection (not graded)",
  contextMenuGroupId: "navigation",
  contextMenuOrder: 0,
  precondition: "editorHasSelection",
  run: (ed) => {
    const sel = ed.getSelection();
    const text = sel ? ed.getModel()?.getValueInRange(sel) : "";
    if (text?.trim()) runSelectionRef.current(text);
  },
});
```

`precondition: "editorHasSelection"` is a Monaco built-in context key, so the item
manages its own availability when nothing is selected — no manual state tracking, and
no stale-closure risk from the enablement check. (Monaco removes the entry from the
menu rather than greying it; see the testing note below.)

The `run` callback closes over the state at mount time, so it must dispatch
through a ref that is reassigned every render — the same pattern the existing
`runRef` / `resetRef` / `hintRef` keyboard handlers already use in this file.

### 4. Results

Reuse the existing Results / Stats / Plan tabs. Two adjustments:

- The pass/fail banner is driven by `result.evaluation`, which is null for a
  scratch run, so it hides itself with no change needed. Verify this rather than
  assume it.
- Add a visible "Scratch run — not graded" badge in the results tab strip
  (`.tabs`, alongside the Results / Stats / Plan tabs), shown only for a scratch
  run. That is the one place the user is already looking after a run, and it is
  the only way to tell a scratch run from a submission, so it is required rather
  than cosmetic. It requires tracking whether the displayed result came from a
  scratch run — a flag held next to `result` in `LessonView` state, not inferred
  from `evaluation === null`, since a genuine graded run can also return a null
  evaluation on the error path.

A scratch run must not overwrite `prevStats`, the stats-delta baseline. Comparing
a fragment's reads against a previous full run would present a meaningless
improvement or regression.

### Menu label

"Run Selection (not graded)" — the qualifier appears at the point of clicking,
which is where the distinction matters. Raised with the user; no objection, so it
stands. Cheap to shorten to "Run Selection" later.

## Testing

Manual verification against the running stack, on a lesson whose solution is
genuinely multi-statement (`CREATE INDEX …; SELECT …`):

1. No selection → the context-menu item is absent. (Monaco filters an action out of the context menu when its `precondition` is false; it does not render a greyed-out entry. Verified by real right-click during the Task 4 regression pass.)
2. Select only the `SELECT` → **Run Selection** returns rows, stats and a plan.
3. That run shows the scratch marker and **no** pass/fail banner.
4. Reset progress for the lesson, then repeat step 2 with SQL that *would* pass if
   graded. Confirm via `GET /api/progress` that the lesson is still unsolved —
   this is the test that matters, since it is the false-completion guard.
5. The graded `Run` button and `Ctrl+Enter` still grade and still record a solve.
6. `npm run build` and a `dotnet build` both clean.

Note that author-testing through the real API records solves in the user's own
progress (a known project gotcha), so step 4 should be run against a lesson whose
progress state is expendable, or progress reset afterwards.

## Risks

- **Low.** The API change is additive with a default that preserves current
  behaviour, and the editor change adds one action without altering existing
  keybindings.
- The main risk is the opposite of the feature working: a scratch run that
  *does* record progress. Step 4 of the test plan exists specifically to catch it.
