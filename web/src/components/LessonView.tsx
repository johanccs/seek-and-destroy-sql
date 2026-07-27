import { useCallback, useEffect, useRef, useState } from "react";
import Editor from "@monaco-editor/react";
import ReactMarkdown from "react-markdown";
import type { LessonDetail, RunResult, RunStats } from "../types";
import { api } from "../api";
import { ResultsPanel } from "./ResultsPanel";
import { ConcurrencyView } from "./ConcurrencyView";
import { TutorPanel } from "./TutorPanel";

export function LessonView({ lesson, onSolved }: { lesson: LessonDetail; onSolved: () => void }) {
  const [sql, setSql] = useState(lesson.startingQuery);
  const [running, setRunning] = useState(false);
  const [result, setResult] = useState<RunResult | null>(null);
  const [prevStats, setPrevStats] = useState<RunStats | null>(null);
  const [hintCount, setHintCount] = useState(0);
  const [solution, setSolution] = useState<string | null>(null);
  const [busy, setBusy] = useState("");
  const [narrativeWidth, setNarrativeWidth] = useState(() => {
    const saved = Number(localStorage.getItem("narrativeWidth"));
    return saved >= 260 && saved <= 1100 ? saved : 380;
  });
  const workspaceRef = useRef<HTMLDivElement>(null);
  const resizing = useRef(false);

  useEffect(() => {
    setSql(lesson.startingQuery);
    setResult(null);
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
      if (r.progress?.newlySolved) onSolved();
    } catch (e) {
      setResult({ success: false, error: String(e), resultSets: [], stats: null, plan: null, messages: [], evaluation: null, progress: null });
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

  const onResizeStart = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    resizing.current = true;
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
  }, []);

  useEffect(() => {
    const onMove = (e: MouseEvent) => {
      if (!resizing.current || !workspaceRef.current) return;
      const left = workspaceRef.current.getBoundingClientRect().left;
      const w = Math.min(1100, Math.max(260, e.clientX - left));
      setNarrativeWidth(w);
    };
    const onUp = () => {
      if (!resizing.current) return;
      resizing.current = false;
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
      setNarrativeWidth((w) => {
        localStorage.setItem("narrativeWidth", String(w));
        return w;
      });
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
  }, []);

  return (
    <div className="lesson">
      <div className="lesson-head">
        <h2>{lesson.title}</h2>
        <div>
          {lesson.topics.map((t) => (
            <span className="topic" key={t}>{t}</span>
          ))}
          <span className="muted">~{lesson.estimatedMinutes} min</span>
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

      <div className="workspace" ref={workspaceRef} style={{ gridTemplateColumns: `${narrativeWidth}px 1fr` }}>
        <div className="narrative">
          <ReactMarkdown>{lesson.narrative}</ReactMarkdown>
          {Array.from({ length: hintCount }).map((_, i) => (
            <div className="hint" key={i}>💡 {lesson.hints[i]}</div>
          ))}
          {solution && (
            <div className="hint" style={{ borderColor: "var(--good)" }}>
              <b>Reference solution loaded into the editor.</b>
            </div>
          )}
          <div className="workspace-resize-handle" onMouseDown={onResizeStart} />
        </div>

        {lesson.isConcurrency && lesson.interleaving ? (
          <ConcurrencyView lessonId={lesson.id} interleaving={lesson.interleaving} />
        ) : (
          <div className="editor-col">
            <div className="toolbar">
              <button className="btn primary" onClick={run} disabled={running}>
                {running ? "Running…" : "▶ Run"}
              </button>
              <button className="btn" onClick={reset}>↺ Reset Lesson</button>
              <button className="btn ghost" onClick={() => setHintCount((c) => Math.min(c + 1, lesson.hints.length))} disabled={hintCount >= lesson.hints.length}>
                💡 Hint ({hintCount}/{lesson.hints.length})
              </button>
              <div className="spacer" />
              <button className="btn ghost" onClick={showSolution}>Show Solution</button>
              {busy && <span className="muted">{busy}</span>}
            </div>
            <div className="editor-wrap">
              <Editor height="100%" theme="vs-dark" defaultLanguage="sql" value={sql} onChange={(v) => setSql(v ?? "")} options={{ minimap: { enabled: false }, fontSize: 13, automaticLayout: true }} />
            </div>
            <ResultsPanel result={result} prevStats={prevStats} />
          </div>
        )}
      </div>
    </div>
  );
}
