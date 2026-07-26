import type { PlanNode, QueryPlan } from "../types";

function Node({ node }: { node: PlanNode }) {
  return (
    <div>
      <div className="pnode">
        <div className="op">
          <span className="phys">{node.physicalOp}</span>
          {node.logicalOp && node.logicalOp !== node.physicalOp && (
            <span className="muted"> ({node.logicalOp})</span>
          )}
          {node.warnings.map((w) => (
            <span className="wbadge" key={w}>
              ⚠ {w}
            </span>
          ))}
        </div>
        {node.object && <div className="obj">{node.object}</div>}
        <div className="rows">
          rows: est {Math.round(node.estimateRows)}
          {node.actualRows != null && ` / actual ${node.actualRows}`} · cost{" "}
          {node.estimatedCostPercent.toFixed(1)}%
        </div>
        <div className="costbar-track">
          <div
            className="costbar-fill"
            style={{ width: `${Math.min(100, node.estimatedCostPercent)}%` }}
          />
        </div>
      </div>
      {node.children.length > 0 && (
        <div className="pchildren">
          {node.children.map((c) => (
            <Node key={c.nodeId} node={c} />
          ))}
        </div>
      )}
    </div>
  );
}

export function PlanTree({ plan }: { plan: QueryPlan | null }) {
  if (!plan || !plan.root) return <div className="muted">No execution plan captured for this run.</div>;
  return (
    <div>
      {plan.missingIndexes.map((mi, i) => (
        <div className="plan-warn missing" key={`mi${i}`}>
          <b>Missing Index</b> (impact {mi.impact.toFixed(1)}%): <code>{mi.statement}</code>
        </div>
      ))}
      {plan.warnings.map((w, i) => (
        <div className="plan-warn" key={`w${i}`}>
          <b>{w.type}</b>
          {w.impact ? ` (impact ${w.impact.toFixed(1)}%)` : ""}: {w.detail}
        </div>
      ))}
      <Node node={plan.root} />
    </div>
  );
}
