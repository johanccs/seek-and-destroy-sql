import { useRef } from "react";
import { NavLink, Outlet } from "react-router";
import { useCurriculum } from "../hooks/useCurriculum";
import { useColumnResize } from "../useColumnResize";
import { difficultyLabel } from "../difficulty";

const LEVEL_TITLES: Record<string, string> = {
  beginner: "Beginner",
  intermediate: "Intermediate",
  advanced: "Advanced",
  expert: "Expert",
};

export default function DesignLayout() {
  const { levels, progress, error } = useCurriculum("design");

  // Its own storage key, so sizing the module list here does not move the
  // lesson list on the performance track. minRight is larger than the
  // performance track's because a module page has three columns to fit.
  const appRef = useRef<HTMLDivElement>(null);
  const { width: sidebarWidth, onResizeStart } = useColumnResize({
    storageKey: "designSidebarWidth",
    defaultWidth: 320,
    min: 220,
    max: 720,
    minRight: 700,
    containerRef: appRef,
  });
  const pct =
    progress && progress.totalLessons
      ? Math.round((progress.solvedLessons / progress.totalLessons) * 100)
      : 0;

  return (
    <div className="app" ref={appRef} style={{ "--sidebar-w": `${sidebarWidth}px` } as React.CSSProperties}>
      <aside className="sidebar">
        <div className="brand">
          <div className="sub">
            Database Design — model schemas on a canvas, then build them for real
          </div>
        </div>
        <div className="overall">
          <div className="lbl">
            <span>Modules complete</span>
            <span>{progress ? `${progress.solvedLessons}/${progress.totalLessons}` : "—"}</span>
          </div>
          <div className="bartrack">
            <div className="barfill" style={{ width: `${pct}%` }} />
          </div>
        </div>

        {error && <div className="hint" style={{ borderColor: "var(--bad)" }}>{error}</div>}

        {levels.map((g) => (
          <div className="level-group" key={g.level}>
            <div className="level-title">
              <span>{LEVEL_TITLES[g.level] ?? g.title}</span>
              <span>{g.lessons.filter((l) => l.solved).length}/{g.lessons.length}</span>
            </div>
            {g.description && <div className="level-desc">{g.description}</div>}
            {g.lessons.length === 0 && <div className="muted search-empty">Modules coming soon.</div>}
            {g.lessons.map((l) => (
              <NavLink
                className={({ isActive }) => `lesson-row ${isActive ? "active" : ""}`}
                key={l.id}
                to={`/design/modules/${l.id}`}
              >
                <span className={`tick ${l.solved ? "solved" : "unsolved"}`}>{l.solved ? "✓" : "○"}</span>
                <span className="t">
                  <span className="name">{l.title}</span>
                  {l.description && <span className="desc">{l.description}</span>}
                  <span className="meta">
                    ~{l.estimatedMinutes}m
                    <span className="difficulty" title="Difficulty (estimated)"> {difficultyLabel(l.estimatedMinutes)}</span>
                  </span>
                </span>
              </NavLink>
            ))}
          </div>
        ))}
        <div className="sidebar-resize-handle rz rz-col" onMouseDown={onResizeStart} />
      </aside>

      <main className="main">
        <Outlet />
      </main>
    </div>
  );
}
