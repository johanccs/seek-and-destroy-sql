import { useState } from "react";
import type { ModuleStep } from "./types";

// What each step kind is called for a learner, and which pane it belongs to.
// The pane class names are the ones ModuleRoute already renders.
const STEP_META: Record<ModuleStep["kind"], { label: string; pane: string }> = {
  read: { label: "Read", pane: "narrative" },
  canvas: { label: "Model", pane: "erd-workspace" },
  sql: { label: "Run", pane: "erd-output" },
};

/**
 * A passive progress map over a module's steps.
 *
 * Passive is the point: it shows where you are and lets you jump, but nothing
 * unlocks and nothing is recorded. A gated sequence would need per-step
 * completion state and an escape hatch, and would fight the learner who
 * already knows the material.
 */
export function StepBar({ steps }: { steps: ModuleStep[] }) {
  const [current, setCurrent] = useState(0);
  if (steps.length === 0) return null;

  return (
    <ol className="stepbar" aria-label="Module steps">
      {steps.map((step, i) => {
        const meta = STEP_META[step.kind];
        return (
          <li key={i}>
            <button
              type="button"
              className={`stepbar-step ${i === current ? "is-current" : ""}`}
              aria-current={i === current ? "step" : undefined}
              onClick={() => {
                setCurrent(i);
                document
                  .querySelector(`.module-body > .${meta.pane}`)
                  ?.scrollIntoView({ behavior: "smooth", block: "nearest" });
              }}
            >
              <span className="stepbar-n">{i + 1}</span>
              <span className="stepbar-label">{meta.label}</span>
              {/* Only the current step shows its prompt. Showing all of them at
                  once pushed the last step off the edge behind a horizontal
                  scroll, which hides the thing the bar exists to advertise —
                  and the prompt is only actionable for the step you are on. */}
              {step.prompt && i === current && (
                <span className="stepbar-prompt">{step.prompt}</span>
              )}
            </button>
          </li>
        );
      })}
    </ol>
  );
}
