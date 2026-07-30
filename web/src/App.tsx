import { useEffect, useRef, useState } from "react";
import type { LessonDetail, LevelGroup, ProgressSummary } from "./types";
import { api } from "./api";
import { useColumnResize } from "./useColumnResize";
import { LessonView } from "./components/LessonView";
import { SettingsView } from "./components/SettingsView";
import { PrivacyView } from "./components/PrivacyView";
import { TermsView } from "./components/TermsView";
import { difficultyLabel } from "./difficulty";

const LEVEL_TITLES: Record<string, string> = {
  beginner: "Beginner",
  intermediate: "Intermediate",
  advanced: "Advanced",
  expert: "Expert",
};

export default function App() {
  const [levels, setLevels] = useState<LevelGroup[]>([]);
  const [progress, setProgress] = useState<ProgressSummary | null>(null);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [lesson, setLesson] = useState<LessonDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showSettings, setShowSettings] = useState(false);
  const [showPrivacy, setShowPrivacy] = useState(false);
  const [showTerms, setShowTerms] = useState(false);
  const [search, setSearch] = useState("");
  const [theme, setTheme] = useState<"dark" | "light">(
    () => (localStorage.getItem("theme") as "dark" | "light") || "dark",
  );
  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
    localStorage.setItem("theme", theme);
  }, [theme]);

  const appRef = useRef<HTMLDivElement>(null);
  const { width: sidebarWidth, onResizeStart } = useColumnResize({
    storageKey: "sidebarWidth",
    defaultWidth: 300,
    min: 220,
    max: 720,
    minRight: 520, // the workspace needs room for narrative + editor
    containerRef: appRef,
  });

  const refresh = async () => {
    try {
      const [lv, pr] = await Promise.all([api.levels(), api.progress()]);
      setLevels(lv);
      setProgress(pr);
      setError(null);
    } catch (e) {
      setError(`Cannot reach API — is it running? (${e})`);
    }
  };

  useEffect(() => {
    refresh();
  }, []);

  useEffect(() => {
    if (!activeId) return;
    api.lesson(activeId).then(setLesson).catch((e) => setError(String(e)));
  }, [activeId]);

  const pct = progress && progress.totalLessons ? Math.round((progress.solvedLessons / progress.totalLessons) * 100) : 0;

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
          <div className="brand-row">
            <h1>⚔️ Seek &amp; Destroy</h1>
            <button
              className="theme-toggle"
              onClick={() => setTheme((t) => (t === "dark" ? "light" : "dark"))}
              title="Toggle light/dark theme"
              aria-label="Toggle light/dark theme"
            >
              {theme === "dark" ? "☀️" : "🌙"}
            </button>
          </div>
          <div className="sub">SQL Performance Playground — tune real T-SQL against a live SQL Server engine</div>
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

        <div
          className={`settings-nav ${showSettings ? "active" : ""}`}
          onClick={() => { setShowSettings(true); setActiveId(null); setShowPrivacy(false); setShowTerms(false); }}
        >
          ⚙ Settings
        </div>

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
              <div className={`lesson-row ${activeId === l.id ? "active" : ""}`} key={l.id} onClick={() => { setActiveId(l.id); setShowSettings(false); setShowPrivacy(false); setShowTerms(false); }}>
                <span className={`tick ${l.solved ? "solved" : "unsolved"}`}>{l.solved ? "✓" : "○"}</span>
                <span className="t">
                  <span className="name">{l.title}</span>
                  {l.description && <span className="desc">{l.description}</span>}
                  <span className="meta">
                    {l.isConcurrency && <span className="badge-conc">concurrency</span>}
                    {l.azureUnsupported && <span className="badge-azure" title="Not available on Azure SQL Database free tier">local-only</span>} ~{l.estimatedMinutes}m
                    <span className="difficulty" title="Difficulty (estimated)"> {difficultyLabel(l.estimatedMinutes)}</span>
                    {l.bestLogicalReads != null && ` · best ${l.bestLogicalReads} reads`}
                  </span>
                </span>
              </div>
            ))}
          </div>
        ))}
        <div className="sidebar-resize-handle" onMouseDown={onResizeStart} />
      </aside>

      <main className="main">
        {showPrivacy ? (
          <PrivacyView />
        ) : showTerms ? (
          <TermsView />
        ) : showSettings ? (
          <SettingsView onChanged={refresh} />
        ) : lesson ? (
          <LessonView lesson={lesson} onSolved={refresh} theme={theme} />
        ) : (
          <div className="empty">
            <div>
              <h2>Select a lesson to begin</h2>
              <p className="muted">Work from Beginner to Expert. Each lesson runs real SQL and grades your fix automatically.</p>
            </div>
          </div>
        )}
      </main>

      <footer className="site-footer">
        <span className="footer-copyright">© 2026 Johan Potgieter</span>
        <nav className="footer-links">
          <button
            className={`footer-link ${showPrivacy ? "active" : ""}`}
            onClick={() => { setShowPrivacy(true); setShowTerms(false); setShowSettings(false); }}
          >
            Privacy
          </button>
          <button
            className={`footer-link ${showTerms ? "active" : ""}`}
            onClick={() => { setShowTerms(true); setShowPrivacy(false); setShowSettings(false); }}
          >
            Terms
          </button>
          <a href="https://github.com/johanccs/seek-and-destroy-sql" target="_blank" rel="noopener">GitHub</a>
        </nav>
        <span className="footer-badge">Built with React + ASP.NET Core</span>
      </footer>
    </div>
  );
}
