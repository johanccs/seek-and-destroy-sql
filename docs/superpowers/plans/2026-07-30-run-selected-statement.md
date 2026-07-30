# Run Selected Statement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user select SQL in the lesson editor, right-click, and run only that selection as an ungraded scratch run.

**Architecture:** An optional `Graded` flag on the existing `/api/lessons/{id}/run` request suppresses pass-condition evaluation and the progress write server-side. The frontend registers one Monaco context-menu action that posts the selected text with `graded: false`, and badges the result so a scratch run is never mistaken for a submission.

**Tech Stack:** ASP.NET Core minimal API (.NET 10), React 18 + TypeScript, Vite, `@monaco-editor/react`, SQL Server 2022 in Docker.

Design spec: `docs/superpowers/specs/2026-07-30-run-selected-statement-design.md`

## Global Constraints

- **No test framework exists in this repo.** There is no API test project and no vitest/jest in `web` (scripts are only `dev`, `build`, `preview`). Verification is therefore integration-level: HTTP calls against the running API, plus in-browser checks. Do not invent unit-test commands; do not add a test harness as part of this plan.
- **API base URL is `http://localhost:5080`** (health: `/api/health`). Not port 5000.
- **`sqlperf-web` serves a baked nginx production build.** Frontend changes are invisible at `http://localhost:5173` until `docker compose up -d --build web`. For iteration prefer `npm --prefix web run dev` on the host, which talks to the same API.
- **Author-testing through the real API records solves in the user's real progress.** Every task that runs a graded query must clear the affected progress row afterwards (commands given inline).
- **Use the PowerShell tool for `docker exec … sqlcmd` commands.** Git Bash mangles the `/opt/...` container path.
- **The live progress table is `SqlPerfDb.dbo.LessonProgress`.** A stale `AppMeta.dbo.LessonProgress` from the pre-single-database migration ALSO still exists, so a `DELETE` against `AppMeta` succeeds and silently clears nothing. Always target `SqlPerfDb`.
- Existing behaviour must not change: `Ctrl+Enter` and the `Run` button stay graded, and concurrency lessons (separate editor, `/run-concurrency` endpoint) are untouched.
- Match the surrounding code's style: no semicolon-splitting of T-SQL anywhere in this feature.

---

### Task 1: Server-side `Graded` flag

The load-bearing task. Everything else is UI; this is the part that makes a false completion impossible.

**Files:**
- Modify: `api/SqlPerf.Api/Models/Contracts.cs:103`
- Modify: `api/SqlPerf.Api/Program.cs:100-124`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `RunRequest(string Sql, bool Graded = true)`. When `Graded` is `false`, `POST /api/lessons/{id}/run` returns `RunResult` with `Evaluation = null` and `Progress` reflecting stored state only. `RunResult`'s shape is unchanged.

- [ ] **Step 1: Add the flag to the request contract**

In `api/SqlPerf.Api/Models/Contracts.cs`, change line 103 from:

```csharp
public sealed record RunRequest(string Sql);
```

to:

```csharp
// Graded=false is a "scratch" run (e.g. running just an editor selection): it
// executes and returns plan/stats, but must never be evaluated or recorded as a
// solve. Grading a fragment is unsafe in both directions — per-table
// maxLogicalReads assumes the graded SELECT runs last in the batch, and
// resultUnchanged compares against a startingQuery baseline.
public sealed record RunRequest(string Sql, bool Graded = true);
```

The default keeps every existing caller behaving exactly as today.

- [ ] **Step 2: Branch the run handler**

In `api/SqlPerf.Api/Program.cs`, the handler currently reads:

```csharp
    var parsed = PlanParser.Parse(art.PlanXml);
    var baseline = await exec.GetBaselineAsync(l);
    var eval = Evaluator.EvaluateQuery(l.Manifest.PassConditions, parsed?.Dto,
        parsed?.RootCost ?? 0, art.Stats, art.ResultSets, baseline);

    ProgressDto prog;
    if (eval.Passed)
        prog = await progress.RecordSolveAsync(id, art.Stats?.TotalLogicalReads, art.Stats?.ElapsedTimeMs);
    else
        prog = await progress.GetAsync(id);

    return Results.Json(new RunResult(true, null, art.ResultSets, art.Stats, parsed?.Dto,
        art.Messages, eval, prog));
```

Replace that block with:

```csharp
    var parsed = PlanParser.Parse(art.PlanXml);

    // Scratch run: execute and report, but do not grade and do not touch progress.
    // GetBaselineAsync is skipped too — it is only an input to grading.
    if (!req.Graded)
        return Results.Json(new RunResult(true, null, art.ResultSets, art.Stats, parsed?.Dto,
            art.Messages, null, await progress.GetAsync(id)));

    var baseline = await exec.GetBaselineAsync(l);
    var eval = Evaluator.EvaluateQuery(l.Manifest.PassConditions, parsed?.Dto,
        parsed?.RootCost ?? 0, art.Stats, art.ResultSets, baseline);

    ProgressDto prog;
    if (eval.Passed)
        prog = await progress.RecordSolveAsync(id, art.Stats?.TotalLogicalReads, art.Stats?.ElapsedTimeMs);
    else
        prog = await progress.GetAsync(id);

    return Results.Json(new RunResult(true, null, art.ResultSets, art.Stats, parsed?.Dto,
        art.Messages, eval, prog));
```

Leave the `if (!art.Success)` early return above untouched — a failed execution already returns before grading, so syntax errors in a selection behave exactly as they do now.

- [ ] **Step 3: Build the API**

```bash
cd X:/Playground/sql-performance && dotnet build api/SqlPerf.Api/SqlPerf.Api.csproj -c Release
```

Expected: build succeeds. A pre-existing `CA2024` warning on `Services/TutorService.cs:143` is unrelated — ignore it, do not fix it here.

- [ ] **Step 4: Deploy the API locally and confirm it is up**

```bash
cd X:/Playground/sql-performance && docker compose up -d --build api
curl -s -m 10 http://localhost:5080/api/health
```

Expected: JSON reporting `lessonsLoaded: 80`.

- [ ] **Step 5: Set up the false-completion test fixture**

Reset b-01's database so the index does not exist yet, then clear its progress row.

```bash
curl -s -X POST -m 120 http://localhost:5080/api/lessons/b-01-table-scan-vs-seek/reset
```

Then, **using the PowerShell tool**:

```powershell
docker exec -i sqlperf-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Sql_Perf_Pass123!' -C -b -Q "DELETE FROM SqlPerfDb.dbo.LessonProgress WHERE LessonId='b-01-table-scan-vs-seek'"
```

- [ ] **Step 6: Run the full graded solution — proves the graded path still works and creates the index**

b-01's real solution is two statements. Write the request body to a file rather than inlining it, to avoid shell quoting problems with the embedded newline. Put these files in a scratch directory outside the repo so they are never committed; the commands below assume you `cd` there first and stay there for steps 8 and 10.

```bash
cat > graded.json <<'JSON'
{"sql":"CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON Orders(CustomerId);\nSELECT * FROM Orders WHERE CustomerId = 42;"}
JSON
curl -s -m 120 -X POST http://localhost:5080/api/lessons/b-01-table-scan-vs-seek/run \
  -H "Content-Type: application/json" --data @graded.json | jq '{passed: .evaluation.passed, solved: .progress.solved, newlySolved: .progress.newlySolved}'
```

Expected: `passed: true`, `solved: true`, `newlySolved: true`. This confirms the default `Graded = true` still grades and still records.

- [ ] **Step 7: Clear progress but LEAVE the index in place**

This is what sets up the false-pass scenario: the index now exists, so the bare `SELECT` alone satisfies all three of b-01's pass conditions (`requireOperator "Index Seek"`, `noOperator "Clustered Index Scan"`, `maxLogicalReads Orders <= 200`).

**Using the PowerShell tool:**

```powershell
docker exec -i sqlperf-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Sql_Perf_Pass123!' -C -b -Q "DELETE FROM SqlPerfDb.dbo.LessonProgress WHERE LessonId='b-01-table-scan-vs-seek'"
```

- [ ] **Step 8: Prove the fragment WOULD falsely pass when graded**

```bash
cat > frag-graded.json <<'JSON'
{"sql":"SELECT * FROM Orders WHERE CustomerId = 42;"}
JSON
curl -s -m 120 -X POST http://localhost:5080/api/lessons/b-01-table-scan-vs-seek/run \
  -H "Content-Type: application/json" --data @frag-graded.json | jq '{passed: .evaluation.passed, solved: .progress.solved}'
```

Expected: `passed: true`, `solved: true` — the SELECT alone passes purely because the index survives from step 6. This is the bug the flag exists to prevent; seeing it here is what makes step 10 meaningful.

- [ ] **Step 9: Clear progress again**

**Using the PowerShell tool:**

```powershell
docker exec -i sqlperf-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Sql_Perf_Pass123!' -C -b -Q "DELETE FROM SqlPerfDb.dbo.LessonProgress WHERE LessonId='b-01-table-scan-vs-seek'"
```

- [ ] **Step 10: The guard — same fragment with `graded: false` must not grade or record**

```bash
cat > frag-scratch.json <<'JSON'
{"sql":"SELECT * FROM Orders WHERE CustomerId = 42;","graded":false}
JSON
curl -s -m 120 -X POST http://localhost:5080/api/lessons/b-01-table-scan-vs-seek/run \
  -H "Content-Type: application/json" --data @frag-scratch.json | jq '{success, evaluation, solved: .progress.solved, rows: .resultSets[0].rowCount, hasPlan: (.plan != null), reads: .stats.totalLogicalReads}'
```

Expected: `success: true`, `evaluation: null`, `solved: false`, with a non-zero `rows`, `hasPlan: true` and a real `reads` value.

The three things that must all hold: `evaluation` is `null`, `solved` is `false`, and results/plan/stats are still fully populated.

- [ ] **Step 11: Confirm progress really is untouched at the API level**

```bash
curl -s -m 10 http://localhost:5080/api/progress | jq '{solvedLessons, totalLessons}'
```

Expected: `solvedLessons` is 0. (`/api/progress` returns only `byLevel`, `solvedLessons` and `totalLessons` — there is no per-lesson `lessons[]` array, so the aggregate count is the signal.) If this shows `solved: true`, the flag is not working — stop and fix before continuing.

- [ ] **Step 12: Commit**

```bash
cd X:/Playground/sql-performance
git add api/SqlPerf.Api/Models/Contracts.cs api/SqlPerf.Api/Program.cs
git commit -m "Add ungraded scratch-run flag to the run endpoint

RunRequest gains Graded=true. When false, /run executes and returns
results, stats and plan but skips the baseline fetch, skips the evaluator
and never calls RecordSolveAsync, so a partial statement cannot be graded
or recorded as a solve.

Verified on b-01: with IX_Orders_CustomerId already present, the bare
SELECT passes all three pass conditions when graded, and records nothing
when graded=false."
```

---

### Task 2: Context-menu "Run Selection"

**Files:**
- Modify: `web/src/api.ts:28-33`
- Modify: `web/src/components/LessonView.tsx` (the `run` function around line 37, and the `<Editor>` at line 188)

**Interfaces:**
- Consumes: `RunRequest.Graded` from Task 1, via the JSON body key `graded`.
- Produces: `api.run(id, sql, graded?)`; a `runSelection(text: string)` function in `LessonView`; a `scratch: boolean` companion to `result` state, consumed by Task 3.

- [ ] **Step 1: Add the `graded` parameter to the API client**

In `web/src/api.ts`, replace the `run` method:

```ts
  run: (id: string, sql: string, graded = true) =>
    fetch(`${BASE}/api/lessons/${id}/run`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sql, graded }),
    }).then(json<RunResult>),
```

Defaulting to `true` leaves the existing `api.run(lesson.id, sql)` call site working unchanged.

- [ ] **Step 2: Track whether the displayed result came from a scratch run**

In `LessonView`, next to the existing `result` state, add:

```ts
  const [scratch, setScratch] = useState(false);
```

Do **not** derive this from `result.evaluation === null`. A failed graded run also returns a null evaluation (the `if (!art.Success)` early return in `Program.cs`), so deriving it would badge a genuine failed submission as a scratch run.

Set it to `false` in the existing graded `run` function, and reset it wherever `result` is cleared. The lesson-change `useEffect` (keyed on `lesson.id`) and `reset` both call `setResult(null)`; add `setScratch(false)` to each.

- [ ] **Step 3: Add the scratch run function**

Place this next to the existing `run` function in `LessonView`. It mirrors `run`'s structure but passes `graded: false` and deliberately does **not** touch `prevStats` or call `onSolved`:

```ts
  const runSelection = async (text: string) => {
    setRunning(true);
    try {
      const r = await api.run(lesson.id, text, false);
      // prevStats is intentionally not updated: comparing a fragment's reads
      // against a previous full run would show a meaningless delta.
      setResult(r);
      setScratch(true);
    } catch (e) {
      setResult({ success: false, error: String(e), resultSets: [], stats: null, plan: null, messages: [], evaluation: null, progress: null });
      setScratch(true);
    } finally {
      setRunning(false);
    }
  };
```

- [ ] **Step 4: Add a live ref for the scratch runner**

The Monaco action's callback is registered once at mount, so it closes over stale state unless it dispatches through a ref. `LessonView` already uses this pattern for `runRef` / `resetRef` / `hintRef`; follow it. Add after those existing refs:

```ts
  const runSelectionRef = useRef(runSelection);
  runSelectionRef.current = runSelection;
```

- [ ] **Step 5: Register the context-menu action on the editor**

Add an `onMount` prop to the `<Editor>` at `LessonView.tsx:188`. Keep every existing prop as-is and add:

```tsx
onMount={(editor) => {
  editor.addAction({
    id: "sqlperf.runSelection",
    label: "Run Selection (not graded)",
    contextMenuGroupId: "navigation",
    contextMenuOrder: 0,
    // Monaco built-in context key: with no selection Monaco filters the item
    // out of the context menu entirely (it is absent, not greyed out), so
    // there is no enablement state to track or keep in sync.
    precondition: "editorHasSelection",
    run: (ed) => {
      const sel = ed.getSelection();
      const text = sel ? ed.getModel()?.getValueInRange(sel) : "";
      if (text && text.trim()) runSelectionRef.current(text);
    },
  });
}}
```

Do not add a keybinding — `Ctrl+Enter` must keep meaning the graded full run.

- [ ] **Step 6: Typecheck and build**

```bash
cd X:/Playground/sql-performance && npm --prefix web run build
```

Expected: succeeds with no errors. The `build` script is `tsc -b && vite build`, so this typechecks and bundles in one step.

- [ ] **Step 7: Verify in the browser**

Start the dev server (faster than rebuilding the nginx image):

```bash
cd X:/Playground/sql-performance && npm --prefix web run dev
```

Open the printed URL, pick lesson **Table Scan vs. Index Seek**, and check:

1. With nothing selected, right-click in the editor → "Run Selection (not graded)" is **absent** from the context menu (Monaco filters it out entirely when its precondition is false, rather than greying it out).
2. Type a second statement so the buffer holds two, e.g.
   `SELECT COUNT(*) FROM Orders;` on line 1 and `SELECT * FROM Orders WHERE CustomerId = 42;` on line 2.
3. Select line 2 only, right-click → **Run Selection (not graded)** → results appear for that statement only (a row set for `CustomerId = 42`, not a count).
4. No pass/fail banner appears.
5. The lesson's tick in the sidebar does not become solved.

- [ ] **Step 8: Commit**

```bash
cd X:/Playground/sql-performance
git add web/src/api.ts web/src/components/LessonView.tsx
git commit -m "Add 'Run Selection' context-menu action to the lesson editor

Registers one Monaco action that posts only the selected text with
graded=false, so it executes as a scratch run. Uses the built-in
editorHasSelection precondition so the item disables itself when nothing
is selected, and dispatches through a ref because the action callback is
registered once at mount.

Ctrl+Enter and the Run button are unchanged and still grade."
```

---

### Task 3: Scratch-run badge

Without this, a successful scratch run is visually indistinguishable from a graded run that produced no verdict.

**Files:**
- Modify: `web/src/components/ResultsPanel.tsx:10` (props) and its `.tabs` block (lines 22-37)
- Modify: `web/src/components/LessonView.tsx` (the `<ResultsPanel>` usage, currently line 190)
- Modify: `web/src/styles.css`

**Interfaces:**
- Consumes: the `scratch: boolean` state from Task 2.
- Produces: `ResultsPanel` accepts a third prop `scratch?: boolean`.

- [ ] **Step 1: Accept the prop**

In `web/src/components/ResultsPanel.tsx`, change the signature from:

```tsx
export function ResultsPanel({ result, prevStats }: { result: RunResult | null; prevStats: RunStats | null }) {
```

to:

```tsx
export function ResultsPanel({ result, prevStats, scratch = false }: { result: RunResult | null; prevStats: RunStats | null; scratch?: boolean }) {
```

- [ ] **Step 2: Render the badge in the tab strip**

In the same file, inside the `.tabs` div, immediately after `<div className="spacer" />` and before the `<FontSizeControl …>`, add:

```tsx
          {scratch && (
            <span className="badge-scratch" title="Only the selected statement ran. Scratch runs are never graded and cannot complete a lesson.">
              Scratch run — not graded
            </span>
          )}
```

Placing it after the spacer puts it on the right of the tab strip, next to the existing font-size control, where the user is already looking after a run.

- [ ] **Step 3: Pass the flag through**

In `web/src/components/LessonView.tsx`, change the `ResultsPanel` usage from:

```tsx
            <ResultsPanel result={result} prevStats={prevStats} />
```

to:

```tsx
            <ResultsPanel result={result} prevStats={prevStats} scratch={scratch} />
```

- [ ] **Step 4: Style the badge**

Append to `web/src/styles.css`, next to the existing `.badge-conc` / `.badge-azure` rules so related styles stay together:

```css
.badge-scratch {
  font-size: 10px;
  background: var(--warn-bg);
  color: var(--warn);
  border: 1px solid var(--warn);
  padding: 1px 6px;
  border-radius: 3px;
  align-self: center;
  margin-right: 8px;
  white-space: nowrap;
}
```

`white-space: nowrap` keeps the badge text on one line. The tab strip itself did NOT wrap originally (`.tabs` had no `flex-wrap`, and `.tab` labels refused to shrink below their min-content width), which meant the badge could be pushed off the right edge and clipped by `.results`' `overflow: hidden` on a narrow editor column. This was fixed by adding `flex-wrap: wrap` to `.tabs` and `flex-shrink: 1; min-width: 0` to `.tab`, so the tab strip now wraps to a second line (or lets tab labels truncate) instead of clipping the badge.

- [ ] **Step 5: Typecheck and build**

```bash
cd X:/Playground/sql-performance && npm --prefix web run build
```

Expected: succeeds with no errors.

- [ ] **Step 6: Verify the badge appears only for scratch runs**

With `npm --prefix web run dev` running, on lesson **Table Scan vs. Index Seek**:

1. Select one statement → **Run Selection (not graded)** → badge reads "Scratch run — not graded", no pass/fail banner.
2. Click the graded **Run** button → badge disappears, pass/fail banner returns.
3. Introduce a deliberate syntax error (e.g. `SELCT 1;`) and click graded **Run** → the error banner shows and the badge is **absent**. This is the case that a derived `evaluation === null` check would have got wrong.
4. Switch to another lesson and back → no badge on the empty results pane.

- [ ] **Step 7: Commit**

```bash
cd X:/Playground/sql-performance
git add web/src/components/ResultsPanel.tsx web/src/components/LessonView.tsx web/src/styles.css
git commit -m "Badge scratch runs in the results tab strip

A scratch run shows no pass/fail banner, so without a marker it looks
identical to a graded run that returned no verdict. Driven by explicit
state rather than evaluation===null, because a failed graded run also has
a null evaluation."
```

---

### Task 4: Regression check and deploy

**Files:** none modified — verification only.

**Interfaces:**
- Consumes: everything from Tasks 1-3.
- Produces: nothing.

- [ ] **Step 1: Rebuild the containers so the baked web image carries the change**

```bash
cd X:/Playground/sql-performance && docker compose up -d --build web && curl -s -m 10 http://localhost:5080/api/health
```

Expected: health reports `lessonsLoaded: 80`. (Rebuilding `web` also recreates `api` as a dependency; harmless.)

- [ ] **Step 2: Confirm the graded path is fully intact end-to-end**

Reset b-01 and clear its progress first — **PowerShell tool** for the sqlcmd line:

```bash
curl -s -X POST -m 120 http://localhost:5080/api/lessons/b-01-table-scan-vs-seek/reset
```

```powershell
docker exec -i sqlperf-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Sql_Perf_Pass123!' -C -b -Q "DELETE FROM SqlPerfDb.dbo.LessonProgress WHERE LessonId='b-01-table-scan-vs-seek'"
```

Then in the browser at `http://localhost:5173`, on **Table Scan vs. Index Seek**: click **Show Solution**, press `Ctrl+Enter`, and confirm the pass banner shows "Solved! Lesson complete." and the sidebar tick turns green. This proves the keyboard path and progress recording still work.

- [ ] **Step 3: Confirm a concurrency lesson is unaffected**

Search the sidebar for "blocking", open **Blocking: A Reader Stuck Behind an Uncommitted Writer**, and confirm its two session editors render and **Run Interleaving** still works. Those use a different editor and the `/run-concurrency` endpoint, so they should be untouched — this is a check that nothing leaked.

- [ ] **Step 4: Leave progress clean**

The graded run in step 2 recorded a real solve. Clear it — **PowerShell tool**:

```powershell
docker exec -i sqlperf-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'Sql_Perf_Pass123!' -C -b -Q "DELETE FROM SqlPerfDb.dbo.LessonProgress WHERE LessonId='b-01-table-scan-vs-seek'"
```

Then confirm via `curl -s http://localhost:5080/api/progress` that b-01 is not solved.

- [ ] **Step 5: Report and hand off**

Summarise for the user: what changed, the verification evidence (especially the Task 1 step 8 vs step 10 contrast), and that the branch is `feat/run-selected-statement` awaiting their decision on merge and push. Do **not** merge or push without being asked — `ci.yml` auto-deploys to Azure on any push to `main`.
