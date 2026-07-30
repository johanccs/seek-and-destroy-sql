import { useEffect, useRef, useState } from "react";
import Editor from "@monaco-editor/react";
import ReactMarkdown from "react-markdown";
import type { LessonDetail, RunResult, RunStats } from "../types";
import { api } from "../api";
import { ResultsPanel } from "./ResultsPanel";
import { ConcurrencyView } from "./ConcurrencyView";
import { TutorPanel } from "./TutorPanel";
import { FontSizeControl, useFontSize } from "./FontSizeControl";
import { useColumnResize } from "../useColumnResize";
import { difficultyLabel } from "../difficulty";

export function LessonView({ lesson, onSolved, theme }: { lesson: LessonDetail; onSolved: () => void; theme: "dark" | "light" }) {
  const [sql, setSql] = useState(lesson.startingQuery);
  const [running, setRunning] = useState(false);
  const [result, setResult] = useState<RunResult | null>(null);
  const [scratch, setScratch] = useState(false);
  const [prevStats, setPrevStats] = useState<RunStats | null>(null);
  const [hintCount, setHintCount] = useState(0);
  const [solution, setSolution] = useState<string | null>(null);
  const [busy, setBusy] = useState("");
  const workspaceRef = useRef<HTMLDivElement>(null);
  const { width: narrativeWidth, onResizeStart } = useColumnResize({
    storageKey: "narrativeWidth",
    defaultWidth: 380,
    min: 260,
    max: 1100,
    minRight: 340, // the SQL editor + results need to stay usable
    containerRef: workspaceRef,
  });
  const narrativeFs = useFontSize("narrative", 14);
  const editorFs = useFontSize("editor", 13);

  useEffect(() => {
    setSql(lesson.startingQuery);
    setResult(null);
    setScratch(false);
    setPrevStats(null);
    setHintCount(0);
    setSolution(null);
  }, [lesson.id]);

  const run = async () => {
    setRunning(true);
    try {
      const r = await api.run(lesson.id, sql);
      setPrevStats(result?.stats ?? null);
      setResult(r);
      setScratch(false);
      if (r.progress?.newlySolved) onSolved();
    } catch (e) {
      setResult({ success: false, error: String(e), resultSets: [], stats: null, plan: null, messages: [], evaluation: null, progress: null });
      setScratch(false);
    } finally {
      setRunning(false);
    }
  };

  const runSelection = async (text: string) => {
    if (running) return;
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

  const reset = async () => {
    setBusy("Resetting lesson database…");
    try {
      await api.reset(lesson.id);
      setSql(lesson.startingQuery);
      setResult(null);
      setScratch(false);
      setPrevStats(null);
    } finally {
      setBusy("");
    }
  };

  const showSolution = async () => {
    const s = await api.solution(lesson.id);
    setSolution(s.solution);
    setSql(s.solution);
  };

  // Keep a live ref so the global keydown listener always calls the current
  // run/reset without needing to re-bind the listener on every render.
  const runRef = useRef(run);
  runRef.current = run;
  const resetRef = useRef(reset);
  resetRef.current = reset;
  const hintRef = useRef(() => setHintCount((c) => Math.min(c + 1, lesson.hints.length)));
  hintRef.current = () => setHintCount((c) => Math.min(c + 1, lesson.hints.length));
  const runSelectionRef = useRef(runSelection);
  runSelectionRef.current = runSelection;

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
        e.preventDefault();
        runRef.current();
      } else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "h") {
        e.preventDefault();
        hintRef.current();
      } else if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === "r") {
        e.preventDefault();
        resetRef.current();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  const printLesson = () => {
    const w = window.open("", "_blank");
    if (!w) return;
    const narrativeHtml = document.querySelector(".narrative .markdown-body")?.innerHTML
      ?? document.querySelector(".narrative")?.innerHTML ?? "";
    w.document.write(`<!doctype html><html><head><title>${lesson.title} — Seek &amp; Destroy</title>
      <style>
        body { font-family: -apple-system, "Segoe UI", sans-serif; max-width: 780px; margin: 40px auto; color: #1c2530; line-height: 1.55; }
        h1 { font-size: 22px; } h2 { font-size: 17px; margin-top: 28px; } code { background: #eef1f5; padding: 1px 5px; border-radius: 4px; }
        pre { background: #eef1f5; padding: 10px; border-radius: 6px; overflow-x: auto; }
        .meta { color: #5b6675; font-size: 13px; margin-bottom: 18px; }
        .hint-box { border-left: 3px solid #a97400; background: #fbf0d6; padding: 8px 12px; margin: 10px 0; border-radius: 4px; }
      </style></head><body>
      <h1>${lesson.title}</h1>
      <div class="meta">${lesson.level} · ${lesson.topics.join(", ")} · ~${lesson.estimatedMinutes} min</div>
      ${narrativeHtml}
      ${lesson.hints.map((h) => `<div class="hint-box">💡 ${h}</div>`).join("")}
      </body></html>`);
    w.document.close();
    w.focus();
    w.print();
  };

  return (
    <div className="lesson">
      <div className="lesson-head">
        <div className="lesson-head-top">
          <h2>{lesson.title}</h2>
          <button className="btn ghost small" onClick={printLesson} title="Print / export this lesson as a study reference">🖨 Print</button>
        </div>
        <div>
          {lesson.topics.map((t) => (
            <span className="topic" key={t}>{t}</span>
          ))}
          <span className="muted">~{lesson.estimatedMinutes} min</span>
          <span className="muted difficulty" title="Difficulty (estimated)">{difficultyLabel(lesson.estimatedMinutes)}</span>
          {lesson.progress.solved && <span className="muted"> · ✅ solved</span>}
        </div>
        {lesson.azureUnsupported && (
          <div className="hint" style={{ borderColor: "var(--warn)" }}>
            ⚠️ This lesson needs a SQL Server tier that supports columnstore indexes
            (Standard S3+, Premium, or vCore General Purpose+). It won't fully work on
            Azure SQL Database's free tier — run it locally via Docker instead.
          </div>
        )}
        <TutorPanel lessonId={lesson.id} />
      </div>

      <div className="workspace" ref={workspaceRef} style={{ "--narrative-w": `${narrativeWidth}px` } as React.CSSProperties}>
        <div className="narrative">
          <div className="narrative-header">
            <span className="muted" style={{ fontSize: 11, textTransform: "uppercase", letterSpacing: ".5px" }}>Lesson</span>
            <FontSizeControl label="Lesson" fontSize={narrativeFs} />
          </div>
          <div className="fontsize-zoom-wrap" style={{ "--panel-zoom": narrativeFs.size / 14 } as React.CSSProperties}>
            <div className="markdown-body">
              <ReactMarkdown>{lesson.narrative}</ReactMarkdown>
            </div>
            {Array.from({ length: hintCount }).map((_, i) => (
              <div className="hint" key={i}>💡 {lesson.hints[i]}</div>
            ))}
            {solution && (
              <div className="hint" style={{ borderColor: "var(--good)" }}>
                <b>Reference solution loaded into the editor.</b>
              </div>
            )}
          </div>
          <div className="workspace-resize-handle" onMouseDown={onResizeStart} />
        </div>

        {lesson.isConcurrency && lesson.interleaving ? (
          <ConcurrencyView lessonId={lesson.id} interleaving={lesson.interleaving} />
        ) : (
          <div className="editor-col">
            <div className="toolbar">
              <button className="btn primary" onClick={run} disabled={running} title="Ctrl+Enter">
                {running ? "Running…" : "▶ Run"}
              </button>
              <button className="btn" onClick={reset} title="Ctrl+Shift+R">↺ Reset Lesson</button>
              <button className="btn ghost" onClick={() => setHintCount((c) => Math.min(c + 1, lesson.hints.length))} disabled={hintCount >= lesson.hints.length} title="Ctrl+H">
                💡 Hint ({hintCount}/{lesson.hints.length})
              </button>
              <div className="spacer" />
              <button className="btn ghost" onClick={showSolution}>Show Solution</button>
              {busy && <span className="muted">{busy}</span>}
              <div className="spacer" />
              <FontSizeControl label="Editor" fontSize={editorFs} />
            </div>
            <div className="editor-wrap">
              <Editor
                height="100%"
                theme={theme === "dark" ? "vs-dark" : "light"}
                defaultLanguage="sql"
                value={sql}
                onChange={(v) => setSql(v ?? "")}
                options={{ minimap: { enabled: false }, fontSize: editorFs.size, automaticLayout: true }}
                onMount={(editor) => {
                  editor.addAction({
                    id: "sqlperf.runSelection",
                    label: "Run Selection (not graded)",
                    contextMenuGroupId: "navigation",
                    contextMenuOrder: 0,
                    // Monaco built-in context key, so there is no enablement state to track
                    // or keep in sync. Note Monaco FILTERS the action out of the context menu
                    // entirely when this is false rather than rendering it greyed out, so with
                    // no selection the item is absent, not disabled. (Verified by real
                    // right-click; the spec originally claimed "greyed out" and was wrong.)
                    precondition: "editorHasSelection",
                    run: (ed) => {
                      const sel = ed.getSelection();
                      const text = sel ? ed.getModel()?.getValueInRange(sel) : "";
                      if (text && text.trim()) runSelectionRef.current(text);
                    },
                  });
                }}
              />
            </div>
            <ResultsPanel result={result} prevStats={prevStats} scratch={scratch} />
          </div>
        )}
      </div>
    </div>
  );
}
