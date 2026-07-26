import { useEffect, useState } from "react";
import type { LessonDetail, LevelGroup, ProgressSummary } from "./types";
import { api } from "./api";
import { LessonView } from "./components/LessonView";
import { SettingsView } from "./components/SettingsView";

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
  const [search, setSearch] = useState("");

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
    <div className="app">
      <aside className="sidebar">
        <div className="brand">
          <h1>⚔️ Seek &amp; Destroy</h1>
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
          onClick={() => { setShowSettings(true); setActiveId(null); }}
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
              <div className={`lesson-row ${activeId === l.id ? "active" : ""}`} key={l.id} onClick={() => { setActiveId(l.id); setShowSettings(false); }}>
                <span className={`tick ${l.solved ? "solved" : "unsolved"}`}>{l.solved ? "✓" : "○"}</span>
                <span className="t">
                  <span className="name">{l.title}</span>
                  {l.description && <span className="desc">{l.description}</span>}
                  <span className="meta">
                    {l.isConcurrency && <span className="badge-conc">concurrency</span>}
                    {l.azureUnsupported && <span className="badge-azure" title="Not available on Azure SQL Database free tier">local-only</span>} ~{l.estimatedMinutes}m
                    {l.bestLogicalReads != null && ` · best ${l.bestLogicalReads} reads`}
                  </span>
                </span>
              </div>
            ))}
          </div>
        ))}
      </aside>

      <main className="main">
        {showSettings ? (
          <SettingsView onChanged={refresh} />
        ) : lesson ? (
          <LessonView lesson={lesson} onSolved={refresh} />
        ) : (
          <div className="empty">
            <div>
              <h2>Select a lesson to begin</h2>
              <p className="muted">Work from Beginner to Expert. Each lesson runs real SQL and grades your fix automatically.</p>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
