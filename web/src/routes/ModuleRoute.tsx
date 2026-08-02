import { useCallback, useEffect, useReducer, useRef, useState } from "react";
import { useParams } from "react-router";
import ReactMarkdown from "react-markdown";
import { api } from "../api";
import { useColumnResize } from "../useColumnResize";
import { PassBanner } from "../components/PassBanner";
import { ErdCanvas } from "../design/ErdCanvas";
import { Inspector, type Selection } from "../design/Inspector";
import { apply, redo, undo, type ErdAction, type History } from "../design/model";
import { emptyModel, type CheckResult, type ModuleDetail } from "../design/types";
import type { Evaluation } from "../types";

const initialHistory: History = { past: [], present: emptyModel(), future: [] };

type HistoryAction = { kind: "do"; action: ErdAction } | { kind: "undo" } | { kind: "redo" };

function historyReducer(h: History, a: HistoryAction): History {
  if (a.kind === "undo") return undo(h);
  if (a.kind === "redo") return redo(h);
  return apply(h, a.action);
}

export default function ModuleRoute() {
  const { moduleId } = useParams<{ moduleId: string }>();
  const [module, setModule] = useState<ModuleDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [history, dispatchHistory] = useReducer(historyReducer, initialHistory);
  const [selection, setSelection] = useState<Selection>(null);
  const [ddl, setDdl] = useState("");
  const [check, setCheck] = useState<CheckResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [hintCount, setHintCount] = useState(0);

  const model = history.present;
  const dispatch = useCallback((action: ErdAction) => dispatchHistory({ kind: "do", action }), []);

  // The properties panel is bottom-docked and draggable, like the results pane
  // in the performance track. Editing a table with several columns needs real
  // room, and a fixed share of the pane was never going to suit every model.
  const bodyRef = useRef<HTMLDivElement>(null);
  const { width: narrativeWidth, onResizeStart: onNarrativeResize } = useColumnResize({
    storageKey: "moduleNarrativeWidth",
    defaultWidth: 340,
    min: 200,
    max: 900,
    minRight: 560, // canvas + output still need room
    containerRef: bodyRef,
    axis: "x",
  });
  const { width: outputWidth, onResizeStart: onOutputResize } = useColumnResize({
    storageKey: "moduleOutputWidth",
    defaultWidth: 380,
    min: 220,
    max: 900,
    minRight: 520,
    containerRef: bodyRef,
    axis: "x-right",
  });

  const workspaceRef = useRef<HTMLElement>(null);
  const { width: inspectorHeight, onResizeStart: onInspectorResize } = useColumnResize({
    storageKey: "erdInspectorHeight",
    defaultWidth: 300,
    min: 90,
    max: 900,
    minRight: 130, // leave at least this much canvas visible above
    containerRef: workspaceRef as React.RefObject<HTMLElement>,
    axis: "y",
  });

  // Load the module and its saved diagram. The generation guard stops a slow
  // response for a previous module from overwriting the current one.
  useEffect(() => {
    if (!moduleId) return;
    let current = true;
    setModule(null);
    setCheck(null);
    setDdl("");
    setError(null);
    Promise.all([api.module(moduleId), api.moduleModel(moduleId)])
      .then(([m, saved]) => {
        if (!current) return;
        setModule(m);
        dispatchHistory({ kind: "do", action: { t: "load", model: saved.model ?? m.startingModel ?? emptyModel() } });
      })
      .catch((e) => current && setError(String(e)));
    return () => {
      current = false;
    };
  }, [moduleId]);

  // Autosave the diagram, debounced. Undo history is deliberately not persisted.
  const firstRender = useRef(true);
  useEffect(() => {
    if (!moduleId || !module) return;
    if (firstRender.current) {
      firstRender.current = false;
      return;
    }
    const t = setTimeout(() => {
      api.saveModuleModel(moduleId, model).catch(() => {
        /* autosave is best-effort; Check and Reset are the durable actions */
      });
    }, 800);
    return () => clearTimeout(t);
  }, [model, moduleId, module]);

  const generate = async () => {
    if (!moduleId) return;
    setError(null);
    try {
      const res = await api.moduleDdl(moduleId, model);
      setDdl(res.ddl);
      if (res.warnings.length) setError(res.warnings.join(" "));
    } catch (e) {
      setError(String(e));
    }
  };

  const runCheck = async () => {
    if (!moduleId) return;
    setBusy(true);
    setError(null);
    try {
      // If the learner edited the DDL, that is what runs — the canvas is an
      // input method, not the graded artefact.
      const res = await api.moduleCheck(moduleId, ddl.trim() ? { sql: ddl } : { model });
      setCheck(res);
      if (res.ddl && !ddl.trim()) setDdl(res.ddl);
      if (!res.success) setError(res.error);
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const reset = async () => {
    if (!moduleId || !module) return;
    setBusy(true);
    try {
      await api.moduleReset(moduleId);
      dispatchHistory({ kind: "do", action: { t: "load", model: module.startingModel ?? emptyModel() } });
      setDdl("");
      setCheck(null);
      setError(null);
    } finally {
      setBusy(false);
    }
  };

  if (error && !module) return <div className="empty"><div className="hint" style={{ borderColor: "var(--bad)" }}>{error}</div></div>;
  if (!module) return <div className="empty">Loading module…</div>;

  const evaluation: Evaluation | null = check?.evaluation ?? null;
  const passedCount = evaluation ? evaluation.conditions.filter((c) => c.passed).length : 0;
  const totalCount = evaluation ? evaluation.conditions.length : 0;

  return (
    <div className="module">
      <div className="lesson-head">
        <div className="lesson-head-top">
          <h2>{module.title}</h2>
          <div className="erd-toolbar">
            <button className="btn small" onClick={() => dispatchHistory({ kind: "undo" })} disabled={history.past.length === 0}>↶ Undo</button>
            <button className="btn small" onClick={() => dispatchHistory({ kind: "redo" })} disabled={history.future.length === 0}>↷ Redo</button>
            <button className="btn small" onClick={() => dispatch({ t: "addEntity", x: 120 + model.entities.length * 40, y: 90 + model.entities.length * 30 })}>+ Table</button>
            <button className="btn small" onClick={generate}>Generate DDL</button>
            <button className="btn primary small" onClick={runCheck} disabled={busy}>
              ▶ {evaluation ? `${passedCount}/${totalCount}` : ""} Check
            </button>
            <button className="btn ghost small" onClick={reset} disabled={busy}>Reset</button>
          </div>
        </div>
        <div>{module.topics.map((t) => <span className="topic" key={t}>{t}</span>)}</div>
      </div>

      <div
        className="module-body"
        ref={bodyRef}
        style={{
          "--module-narrative-w": `${narrativeWidth}px`,
          "--module-output-w": `${outputWidth}px`,
        } as React.CSSProperties}
      >
        <section className="narrative">
          <div className="markdown-body">
            <ReactMarkdown>{module.narrative}</ReactMarkdown>
          </div>
          {module.hints.length > 0 && (
            <div className="hints">
              {module.hints.slice(0, hintCount).map((h, i) => (
                <div className="hint" key={i}>{h}</div>
              ))}
              {hintCount < module.hints.length && (
                <button className="btn ghost small" onClick={() => setHintCount((c) => c + 1)}>
                  Show hint {hintCount + 1} of {module.hints.length}
                </button>
              )}
            </div>
          )}
        </section>

        <div className="rz rz-col" onMouseDown={onNarrativeResize} title="Drag to resize the lesson text" />

        <section
          className="erd-workspace"
          ref={workspaceRef}
          style={{ "--inspector-h": `${inspectorHeight}px` } as React.CSSProperties}
        >
          <ErdCanvas
            model={model}
            dispatch={dispatch}
            onSelect={setSelection}
            selectedId={selection?.id ?? null}
          />
          <div className="erd-inspector-resize-handle rz rz-row" onMouseDown={onInspectorResize} />
          <Inspector model={model} selection={selection} dispatch={dispatch} />
        </section>

        <div className="rz rz-col" onMouseDown={onOutputResize} title="Drag to resize the DDL pane" />

        <section className="erd-output">
          {evaluation && <PassBanner evaluation={evaluation} newlySolved={!!check?.progress?.newlySolved} />}
          {error && <div className="hint" style={{ borderColor: "var(--bad)" }}>{error}</div>}
          <div className="props-sub">Generated DDL — this is exactly what runs</div>
          <textarea
            className="erd-ddl"
            value={ddl}
            spellCheck={false}
            placeholder="Press “Generate DDL” to turn your model into T-SQL. You can edit it before running — or ignore the canvas and write it yourself."
            onChange={(e) => setDdl(e.target.value)}
          />
        </section>
      </div>
    </div>
  );
}
