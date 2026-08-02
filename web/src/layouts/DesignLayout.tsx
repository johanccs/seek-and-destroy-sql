import { NavLink, Outlet } from "react-router";
import { useCurriculum } from "../hooks/useCurriculum";
import { difficultyLabel } from "../difficulty";

const LEVEL_TITLES: Record<string, string> = {
  beginner: "Beginner",
  intermediate: "Intermediate",
  advanced: "Advanced",
  expert: "Expert",
};

export default function DesignLayout() {
  const { levels, progress, error } = useCurriculum("design");
  const pct =
    progress && progress.totalLessons
      ? Math.round((progress.solvedLessons / progress.totalLessons) * 100)
      : 0;

  return (
    <div className="app" style={{ "--sidebar-w": "320px" } as React.CSSProperties}>
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
      </aside>

      <main className="main">
        <Outlet />
      </main>
    </div>
  );
}
