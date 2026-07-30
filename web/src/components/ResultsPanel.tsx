import { useState } from "react";
import type { RunResult, RunStats } from "../types";
import { PlanTree } from "./PlanTree";
import { StatsPanel } from "./StatsPanel";
import { PassBanner } from "./PassBanner";
import { FontSizeControl, useFontSize } from "./FontSizeControl";

type Tab = "results" | "stats" | "plan" | "messages";

export function ResultsPanel({ result, prevStats, scratch = false }: { result: RunResult | null; prevStats: RunStats | null; scratch?: boolean }) {
  const [tab, setTab] = useState<Tab>("results");
  const resultsFs = useFontSize("results", 13);
  if (!result) return <div className="tab-body muted">Run a query to see results, statistics and the execution plan.</div>;

  const planWarnCount = (result.plan?.warnings.length ?? 0) + (result.plan?.missingIndexes.length ?? 0);

  return (
    <div className="results">
      <div>
        <PassBanner evaluation={result.evaluation} newlySolved={result.progress?.newlySolved} />
        {result.error && <div className="banner fail"><div className="err">{result.error}</div></div>}
        <div className="tabs">
          <div className={`tab ${tab === "results" ? "active" : ""}`} onClick={() => setTab("results")}>
            Results
          </div>
          <div className={`tab ${tab === "stats" ? "active" : ""}`} onClick={() => setTab("stats")}>
            Statistics
          </div>
          <div className={`tab ${tab === "plan" ? "active" : ""}`} onClick={() => setTab("plan")}>
            Execution Plan {planWarnCount > 0 && <span className="dot">●</span>}
          </div>
          <div className={`tab ${tab === "messages" ? "active" : ""}`} onClick={() => setTab("messages")}>
            Messages
          </div>
          <div className="spacer" />
          {scratch && (
            <span className="badge-scratch" title="Only the selected statement ran. Scratch runs are never graded and cannot complete a lesson.">
              Scratch run — not graded
            </span>
          )}
          <FontSizeControl label="Results" fontSize={resultsFs} />
        </div>
      </div>

      <div className="tab-body fontsize-zoom-wrap" style={{ "--panel-zoom": resultsFs.size / 13 } as React.CSSProperties}>
        {tab === "results" &&
          (result.resultSets.length === 0 ? (
            <div className="muted">No rows returned.</div>
          ) : (
            result.resultSets.map((rs, i) => (
              <div key={i} style={{ marginBottom: 16 }}>
                <table className="grid">
                  <thead>
                    <tr>{rs.columns.map((c) => <th key={c}>{c}</th>)}</tr>
                  </thead>
                  <tbody>
                    {rs.rows.map((r, ri) => (
                      <tr key={ri}>{r.map((cell, ci) => <td key={ci}>{cell === null ? "NULL" : String(cell)}</td>)}</tr>
                    ))}
                  </tbody>
                </table>
                {rs.truncated && <div className="truncated">Showing first {rs.rows.length} of {rs.rowCount}+ rows (truncated).</div>}
              </div>
            ))
          ))}
        {tab === "stats" && <StatsPanel stats={result.stats} prev={prevStats} />}
        {tab === "plan" && <PlanTree plan={result.plan} />}
        {tab === "messages" && (
          <pre style={{ whiteSpace: "pre-wrap", fontSize: 12 }}>{result.messages.join("\n") || "(no messages)"}</pre>
        )}
      </div>
    </div>
  );
}
