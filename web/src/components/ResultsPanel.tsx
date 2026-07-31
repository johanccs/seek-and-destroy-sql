import { useState } from "react";
import type { RunResult, RunStats, SchemaInfo } from "../types";
import { PlanTree } from "./PlanTree";
import { StatsPanel } from "./StatsPanel";
import { PassBanner } from "./PassBanner";
import { FontSizeControl, useFontSize } from "./FontSizeControl";

type Tab = "results" | "stats" | "plan" | "messages" | "properties";

export function ResultsPanel({ result, prevStats, scratch = false, onResizeStart, schema, schemaError }: { result: RunResult | null; prevStats: RunStats | null; scratch?: boolean; onResizeStart?: (e: React.MouseEvent) => void; schema?: SchemaInfo | null; schemaError?: string | null }) {
  const [tab, setTab] = useState<Tab>("results");
  const resultsFs = useFontSize("results", 13);

  const planWarnCount = (result?.plan?.warnings.length ?? 0) + (result?.plan?.missingIndexes.length ?? 0);

  return (
    <div className="results">
      {onResizeStart && <div className="results-resize-handle" onMouseDown={onResizeStart} title="Drag to resize the results pane" />}
      <div>
        {result && <PassBanner evaluation={result.evaluation} newlySolved={result.progress?.newlySolved} />}
        {result?.error && <div className="banner fail"><div className="err">{result.error}</div></div>}
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
          <div className={`tab ${tab === "properties" ? "active" : ""}`} onClick={() => setTab("properties")}>
            Properties
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
        {tab === "results" && (
          !result ? <div className="muted">Run a query to see results, statistics and the execution plan.</div>
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
        {tab === "stats" && (
          !result ? <div className="muted">Run a query to see results, statistics and the execution plan.</div>
          : <StatsPanel stats={result.stats} prev={prevStats} />
        )}
        {tab === "plan" && (
          !result ? <div className="muted">Run a query to see results, statistics and the execution plan.</div>
          : <PlanTree plan={result.plan} />
        )}
        {tab === "messages" && (
          !result ? <div className="muted">Run a query to see results, statistics and the execution plan.</div>
          : <pre style={{ whiteSpace: "pre-wrap", fontSize: 12 }}>{result.messages.join("\n") || "(no messages)"}</pre>
        )}
        {tab === "properties" && (
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
