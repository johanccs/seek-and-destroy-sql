import { useState } from "react";
import type { RunResult, RunStats, SchemaInfo } from "../types";
import { PlanTree } from "./PlanTree";
import { StatsPanel } from "./StatsPanel";
import { PassBanner } from "./PassBanner";
import { FontSizeControl, useFontSize } from "./FontSizeControl";

type Tab = "results" | "stats" | "plan" | "messages" | "properties";

const ALL_TABS: Tab[] = ["results", "stats", "plan", "messages", "properties"];

// `tabs` narrows the strip for callers the extra tabs would only confuse. The
// design track runs scratch SELECTs to make an anomaly visible; an execution
// plan or a logical-read count teaches nothing there, and an empty tab invites
// the learner to go looking for something that was never the point.
export function ResultsPanel({ result, prevStats, scratch = false, onResizeStart, schema, schemaError, tabs = ALL_TABS }: { result: RunResult | null; prevStats: RunStats | null; scratch?: boolean; onResizeStart?: (e: React.MouseEvent) => void; schema?: SchemaInfo | null; schemaError?: string | null; tabs?: Tab[] }) {
  const [tab, setTab] = useState<Tab>(tabs[0] ?? "results");
  const resultsFs = useFontSize("results", 13);

  // A restricted strip must not leave a hidden tab selected — the body would
  // render content with no lit tab to explain where it came from.
  const active = tabs.includes(tab) ? tab : (tabs[0] ?? "results");

  // The empty-state copy has to match the strip it is sitting under: promising
  // statistics and an execution plan to a design learner who has neither tab is
  // just a dead end with a friendly tone.
  const emptyMsg = tabs.includes("plan")
    ? "Run a query to see results, statistics and the execution plan."
    : "Run a query to see its results.";

  const planWarnCount = (result?.plan?.warnings.length ?? 0) + (result?.plan?.missingIndexes.length ?? 0);

  return (
    <div className="results">
      {onResizeStart && <div className="results-resize-handle rz rz-row" onMouseDown={onResizeStart} title="Drag to resize the results pane" />}
      <div>
        {result && <PassBanner evaluation={result.evaluation} newlySolved={result.progress?.newlySolved} />}
        {result?.error && <div className="banner fail"><div className="err">{result.error}</div></div>}
        <div className="tabs">
          {tabs.includes("results") && (
            <div className={`tab ${active === "results" ? "active" : ""}`} onClick={() => setTab("results")}>
              Results
            </div>
          )}
          {tabs.includes("stats") && (
            <div className={`tab ${active === "stats" ? "active" : ""}`} onClick={() => setTab("stats")}>
              Statistics
            </div>
          )}
          {tabs.includes("plan") && (
            <div className={`tab ${active === "plan" ? "active" : ""}`} onClick={() => setTab("plan")}>
              Execution Plan {planWarnCount > 0 && <span className="dot">●</span>}
            </div>
          )}
          {tabs.includes("messages") && (
            <div className={`tab ${active === "messages" ? "active" : ""}`} onClick={() => setTab("messages")}>
              Messages
            </div>
          )}
          {tabs.includes("properties") && (
            <div className={`tab ${active === "properties" ? "active" : ""}`} onClick={() => setTab("properties")}>
              Properties
            </div>
          )}
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
        {active === "results" && (
          !result ? <div className="muted">{emptyMsg}</div>
          : result.resultSets.length === 0 ? (
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
        {active === "stats" && (
          !result ? <div className="muted">{emptyMsg}</div>
          : <StatsPanel stats={result.stats} prev={prevStats} />
        )}
        {active === "plan" && (
          !result ? <div className="muted">{emptyMsg}</div>
          : <PlanTree plan={result.plan} />
        )}
        {active === "messages" && (
          !result ? <div className="muted">{emptyMsg}</div>
          : <pre style={{ whiteSpace: "pre-wrap", fontSize: 12 }}>{result.messages.join("\n") || "(no messages)"}</pre>
        )}
        {active === "properties" && (
          schemaError ? <div className="err">Could not load table properties: {schemaError}</div>
          : !schema ? <div className="muted">Loading table properties…</div>
          : !schema.seeded ? <div className="muted">This lesson's data hasn't been created yet. Run a query or click Reset Lesson, then these properties will appear.</div>
          : schema.tables.length === 0 ? <div className="muted">This lesson has no tables.</div>
          : (
            <>
              {schema.tables.map((t) => (
                <div className="props-table" key={t.name}>
                  <h4>{t.name} <span className="muted">— {t.rowCount.toLocaleString()} rows</span></h4>

                  <div className="props-sub">Columns</div>
                  <table className="grid">
                    <thead><tr><th>Name</th><th>Type</th><th>Null</th><th>Key</th></tr></thead>
                    <tbody>
                      {t.columns.map((c) => (
                        <tr key={c.name}>
                          <td>{c.name}</td>
                          <td>{c.dataType}{c.isIdentity && <span className="muted"> identity</span>}</td>
                          <td>{c.nullable ? "NULL" : "NOT NULL"}</td>
                          <td>{c.inPrimaryKey ? <span title="Primary key">🔑</span> : ""}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>

                  <div className="props-sub">Indexes</div>
                  {t.indexes.length === 0 ? (
                    <div className="muted props-none">No indexes on this table.</div>
                  ) : (
                    <table className="grid">
                      <thead><tr><th>Name</th><th>Type</th><th>Unique</th><th>Key columns</th><th>Included</th><th>Filter</th></tr></thead>
                      <tbody>
                        {t.indexes.map((i) => (
                          <tr key={i.name}>
                            <td>{i.isPrimaryKey && <span title="Primary key">🔑 </span>}{i.name}</td>
                            <td>{i.type}</td>
                            <td>{i.isUnique ? "Yes" : "No"}</td>
                            <td>{i.keyColumns}</td>
                            <td>{i.includedColumns || <span className="muted">—</span>}</td>
                            <td>{i.filter || <span className="muted">—</span>}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              ))}
            </>
          )
        )}
      </div>
    </div>
  );
}
