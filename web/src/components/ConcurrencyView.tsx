import { useState } from "react";
import Editor from "@monaco-editor/react";
import type { ConcurrencyResult, Interleaving, InterleavingStep } from "../types";
import { api } from "../api";
import { PassBanner } from "./PassBanner";

function stepsToText(steps: InterleavingStep[]): string {
  return steps.map((s) => `-- afterMs: ${s.afterMs}\n${s.sql}`).join("\n\n");
}

// Parse the editor text back into steps using the "-- afterMs: N" markers.
function textToSteps(text: string): InterleavingStep[] {
  const blocks = text.split(/-- afterMs:\s*(\d+)/).slice(1);
  const steps: InterleavingStep[] = [];
  for (let i = 0; i < blocks.length; i += 2) {
    steps.push({ afterMs: parseInt(blocks[i], 10) || 0, sql: (blocks[i + 1] || "").trim() });
  }
  return steps;
}

export function ConcurrencyView({ lessonId, interleaving }: { lessonId: string; interleaving: Interleaving }) {
  const [a, setA] = useState(stepsToText(interleaving.sessions.A));
  const [b, setB] = useState(stepsToText(interleaving.sessions.B));
  const [running, setRunning] = useState(false);
  const [res, setRes] = useState<ConcurrencyResult | null>(null);

  const run = async () => {
    setRunning(true);
    setRes(null);
    try {
      setRes(await api.runConcurrency(lessonId, { A: textToSteps(a), B: textToSteps(b) }));
    } catch (e) {
      setRes({
        outcome: "error",
        deadlockVictim: null,
        timeline: [],
        deadlockGraphXml: null,
        evaluation: { passed: false, conditions: [{ type: "error", label: "Request failed", passed: false, detail: String(e) }] },
        progress: null,
      });
    } finally {
      setRunning(false);
    }
  };

  return (
    <div className="conc">
      <div className="hint">{interleaving.description}</div>
      <div className="sessions">
        <div className="session-panel">
          <div className="head" style={{ color: "var(--accent)" }}>Session A</div>
          <Editor height="200px" theme="vs-dark" defaultLanguage="sql" value={a} onChange={(v) => setA(v ?? "")} options={{ minimap: { enabled: false }, fontSize: 12 }} />
        </div>
        <div className="session-panel">
          <div className="head" style={{ color: "var(--accent-2)" }}>Session B</div>
          <Editor height="200px" theme="vs-dark" defaultLanguage="sql" value={b} onChange={(v) => setB(v ?? "")} options={{ minimap: { enabled: false }, fontSize: 12 }} />
        </div>
      </div>
      <div>
        <button className="btn primary" onClick={run} disabled={running}>
          {running ? "Running interleaving…" : "▶ Run Interleaving"}
        </button>
      </div>
      {res && (
        <div>
          <div style={{ marginBottom: 10 }}>
            Outcome: <span className={`outcome ${res.outcome}`}>{res.outcome}</span>
            {res.deadlockVictim && <span className="muted"> — victim: Session {res.deadlockVictim}</span>}
          </div>
          <PassBanner evaluation={res.evaluation} newlySolved={res.progress?.newlySolved} />
          <div className="timeline">
            <div className="lane-head muted" style={{ fontWeight: 600, marginBottom: 6 }}>
              <div>t (ms)</div>
              <div>event</div>
            </div>
            {res.timeline.length === 0 && <div className="muted">No timeline events captured.</div>}
            {res.timeline.map((e, i) => (
              <div className={`evt ${e.event.includes("blocked") ? "blocked" : ""} ${e.event.includes("victim") ? "victim" : ""}`} key={i}>
                <div>{e.tMs}</div>
                <div className={`sess ${e.session}`}>{e.session}</div>
                <div>
                  <b>{e.event}</b> — {e.detail}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
