import { useRef, useState } from "react";
import { NavLink, Outlet } from "react-router";
import type { LevelGroup } from "../types";
import { useCurriculum } from "../hooks/useCurriculum";
import { useColumnResize } from "../useColumnResize";
import { difficultyLabel } from "../difficulty";

export type PerfOutletContext = { refresh: () => void };

const LEVEL_TITLES: Record<string, string> = {
  beginner: "Beginner",
  intermediate: "Intermediate",
  advanced: "Advanced",
  expert: "Expert",
};

// The SQL-performance track: lesson navigator on the left, lesson on the right.
// Lifted out of App.tsx unchanged apart from routing — the markup and CSS class
// names are the same, so the existing stylesheet still applies.
export default function PerfLayout() {
  const { levels, progress, error, refresh } = useCurriculum("perf");
  const [search, setSearch] = useState("");

  const appRef = useRef<HTMLDivElement>(null);
  const { width: sidebarWidth, onResizeStart } = useColumnResize({
    storageKey: "sidebarWidth",
    defaultWidth: 300,
    min: 220,
    max: 720,
    minRight: 520, // the workspace needs room for narrative + editor
    containerRef: appRef,
  });

  const pct =
    progress && progress.totalLessons
      ? Math.round((progress.solvedLessons / progress.totalLessons) * 100)
      : 0;

  const q = search.trim().toLowerCase();
  const matches = (l: LevelGroup["lessons"][number]) =>
    !q ||
    l.title.toLowerCase().includes(q) ||
    l.description.toLowerCase().includes(q) ||
    l.topics.some((t) => t.toLowerCase().includes(q));
  const filteredLevels = levels
    .map((g) => ({ ...g, lessons: g.lessons.filter(matches) }))
    .filter((g) => g.lessons.length > 0);

  return (
    <div className="app" ref={appRef} style={{ "--sidebar-w": `${sidebarWidth}px` } as React.CSSProperties}>
      <aside className="sidebar">
        <div className="brand">
          <div className="sub">
            SQL Performance Playground — tune real T-SQL against a live SQL Server engine
          </div>
        </div>
        <div className="overall">
          <div className="lbl">
            <span>Overall progress</span>
            <span>{progress ? `${progress.solvedLessons}/${progress.totalLessons}` : "—"}</span>
          </div>
          <div className="bartrack">
            <div className="barfill" style={{ width: `${pct}%` }} />
          </div>
        </div>

        {error && <div className="hint" style={{ borderColor: "var(--bad)" }}>{error}</div>}

        <div className="search-box">
          <input
            type="text"
            placeholder="Search lessons (title, topic)…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button className="search-clear" onClick={() => setSearch("")} aria-label="Clear search">×</button>
          )}
        </div>
        {q && filteredLevels.length === 0 && (
          <div className="muted search-empty">No lessons match "{search}".</div>
        )}

        {filteredLevels.map((g) => (
          <div className="level-group" key={g.level}>
            <div className="level-title">
              <span>{LEVEL_TITLES[g.level] ?? g.title}</span>
              <span>{g.lessons.filter((l) => l.solved).length}/{g.lessons.length}</span>
            </div>
            {g.description && <div className="level-desc">{g.description}</div>}
            {g.lessons.map((l) => (
              <NavLink
                className={({ isActive }) => `lesson-row ${isActive ? "active" : ""}`}
                key={l.id}
                to={`/perf/lessons/${l.id}`}
              >
                <span className={`tick ${l.solved ? "solved" : "unsolved"}`}>{l.solved ? "✓" : "○"}</span>
                <span className="t">
                  <span className="name">{l.title}</span>
                  {l.description && <span className="desc">{l.description}</span>}
                  <span className="meta">
                    {l.isConcurrency && <span className="badge-conc">concurrency</span>}
                    {l.azureUnsupported && (
                      <span className="badge-azure" title="Not available on Azure SQL Database free tier">local-only</span>
                    )} ~{l.estimatedMinutes}m
                    <span className="difficulty" title="Difficulty (estimated)"> {difficultyLabel(l.estimatedMinutes)}</span>
                    {l.bestLogicalReads != null && ` · best ${l.bestLogicalReads} reads`}
                  </span>
                </span>
              </NavLink>
            ))}
          </div>
        ))}
        <div className="sidebar-resize-handle rz rz-col" onMouseDown={onResizeStart} />
      </aside>

      <main className="main">
        {/* refresh re-fetches levels+progress so a solve turns the sidebar tick
            green immediately, as it did before routing. */}
        <Outlet context={{ refresh } satisfies PerfOutletContext} />
      </main>
    </div>
  );
}
