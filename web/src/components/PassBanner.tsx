import type { Evaluation } from "../types";

export function PassBanner({ evaluation, newlySolved }: { evaluation: Evaluation | null; newlySolved?: boolean }) {
  if (!evaluation) return null;
  return (
    <div className={`banner ${evaluation.passed ? "pass" : "fail"}`}>
      <div className="h">
        {evaluation.passed ? (
          <>✅ {newlySolved ? "Solved! Lesson complete." : "All conditions pass."}</>
        ) : (
          <>❌ Not solved yet — {evaluation.conditions.filter((c) => !c.passed).length} condition(s) failing.</>
        )}
      </div>
      {evaluation.conditions.map((c, i) => (
        <div className="cond" key={i}>
          <span className={`ic ${c.passed ? "ok" : "no"}`}>{c.passed ? "✓" : "✗"}</span>
          <span>{c.label}</span>
          {c.detail && <span className="detail">— {c.detail}</span>}
        </div>
      ))}
    </div>
  );
}
