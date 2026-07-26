import { useEffect, useState } from "react";
import { api } from "../api";

interface Info {
  sqlServerHost: string;
  lessonsLoaded: number;
  progress: { totalLessons: number; solvedLessons: number };
}

type Busy = "" | "reseed" | "resetProgress" | "recreate";

export function SettingsView({ onChanged }: { onChanged: () => void }) {
  const [info, setInfo] = useState<Info | null>(null);
  const [busy, setBusy] = useState<Busy>("");
  const [message, setMessage] = useState<string | null>(null);
  const [confirming, setConfirming] = useState<Busy>("");
  const [keepData, setKeepData] = useState(false);
  const [steps, setSteps] = useState<{ step: string; success: boolean; output: string }[]>([]);

  const load = () => api.settingsInfo().then(setInfo).catch(() => setInfo(null));
  useEffect(() => { load(); }, []);

  async function reseedAll() {
    setBusy("reseed");
    setMessage(null);
    try {
      const r = await api.resetAllDatabases();
      setMessage(
        r.failed > 0
          ? `Recreated ${r.lessonsReset} lesson databases in ${r.elapsedMs} ms — ${r.failed} failed: ${r.failures.join("; ")}`
          : `Recreated all ${r.lessonsReset} lesson databases in ${r.elapsedMs} ms.`,
      );
      onChanged();
      load();
    } catch (e) {
      setMessage(`Failed: ${(e as Error).message}`);
    } finally {
      setBusy("");
      setConfirming("");
    }
  }

  async function resetProgress() {
    setBusy("resetProgress");
    setMessage(null);
    try {
      const r = await api.resetProgress();
      setMessage(`Cleared progress for ${r.rowsCleared} lesson(s).`);
      onChanged();
      load();
    } catch (e) {
      setMessage(`Failed: ${(e as Error).message}`);
    } finally {
      setBusy("");
      setConfirming("");
    }
  }

  async function recreateContainer() {
    setBusy("recreate");
    setMessage("Recreating the SQL Server container — this can take a couple of minutes…");
    setSteps([]);
    try {
      const r = await api.recreateSqlContainer(keepData);
      setSteps(r.steps);
      setMessage(
        r.success
          ? `Done in ${(r.elapsedMs / 1000).toFixed(0)}s. Reseeded ${r.reseed?.lessonsReset ?? 0} lesson databases.`
          : `Failed after ${(r.elapsedMs / 1000).toFixed(0)}s — see steps below.`,
      );
      onChanged();
      load();
    } catch (e) {
      setMessage(`Failed: ${(e as Error).message}`);
    } finally {
      setBusy("");
      setConfirming("");
    }
  }

  return (
    <div className="settings-view">
      <h2>Settings</h2>
      <p className="muted">
        Environment status and database administration. These actions run real database
        operations — no manual scripts needed.
      </p>

      <section className="settings-section">
        <h3>Environment</h3>
        {info ? (
          <table className="settings-table">
            <tbody>
              <tr><td>SQL Server host</td><td>{info.sqlServerHost}</td></tr>
              <tr><td>Lessons loaded</td><td>{info.lessonsLoaded}</td></tr>
              <tr><td>Progress</td><td>{info.progress.solvedLessons} / {info.progress.totalLessons} solved</td></tr>
            </tbody>
          </table>
        ) : (
          <p className="muted">Unable to reach the API.</p>
        )}
      </section>

      <section className="settings-section">
        <h3>Database setup</h3>
        <p className="muted">
          Recreate every lesson's database from its <code>seed.sql</code>. Use this after a
          fresh install, or after the SQL Server container/data volume was recreated (see
          the disaster-recovery section below) — no manual SQL scripts required.
        </p>
        {confirming === "reseed" ? (
          <div className="settings-confirm">
            <span>This drops and recreates all {info?.lessonsLoaded ?? ""} lesson databases. Continue?</span>
            <button className="btn primary" disabled={busy !== ""} onClick={reseedAll}>
              {busy === "reseed" ? "Working…" : "Yes, recreate all databases"}
            </button>
            <button className="btn" disabled={busy !== ""} onClick={() => setConfirming("")}>Cancel</button>
          </div>
        ) : (
          <button className="btn" disabled={busy !== ""} onClick={() => setConfirming("reseed")}>
            Reset All Lesson Databases
          </button>
        )}
      </section>

      <section className="settings-section">
        <h3>Progress</h3>
        <p className="muted">
          Clear all recorded lesson-completion progress and start fresh.
        </p>
        {confirming === "resetProgress" ? (
          <div className="settings-confirm">
            <span>This clears solved status for every lesson. Continue?</span>
            <button className="btn primary" disabled={busy !== ""} onClick={resetProgress}>
              {busy === "resetProgress" ? "Working…" : "Yes, reset my progress"}
            </button>
            <button className="btn" disabled={busy !== ""} onClick={() => setConfirming("")}>Cancel</button>
          </div>
        ) : (
          <button className="btn" disabled={busy !== ""} onClick={() => setConfirming("resetProgress")}>
            Reset My Progress
          </button>
        )}
      </section>

      <section className="settings-section">
        <h3>Disaster recovery</h3>
        <p className="muted">
          If the SQL Server container or its image is deleted (or you just want a
          guaranteed-clean SQL Server), this deletes the <code>sqlperf-sqlserver</code>{" "}
          container and image, pulls a fresh SQL Server 2022 image, recreates the
          container, waits for it to become healthy, and reseeds every lesson database —
          fully automated, no manual scripts.
        </p>
        <label className="settings-checkbox">
          <input
            type="checkbox"
            checked={keepData}
            onChange={(e) => setKeepData(e.target.checked)}
            disabled={busy !== ""}
          />
          Keep existing data volume (skip wiping lesson/progress data)
        </label>
        {confirming === "recreate" ? (
          <div className="settings-confirm">
            <span>
              This deletes the SQL container/image{keepData ? "" : " and all its data"} and
              takes a couple of minutes. Continue?
            </span>
            <button className="btn primary" disabled={busy !== ""} onClick={recreateContainer}>
              {busy === "recreate" ? "Working…" : "Yes, recreate the SQL container"}
            </button>
            <button className="btn" disabled={busy !== ""} onClick={() => setConfirming("")}>Cancel</button>
          </div>
        ) : (
          <button className="btn" disabled={busy !== ""} onClick={() => setConfirming("recreate")}>
            Recreate SQL Server Container
          </button>
        )}

        {steps.length > 0 && (
          <table className="settings-table settings-steps">
            <tbody>
              {steps.map((s, i) => (
                <tr key={i}>
                  <td>{s.success ? "✓" : "✗"}</td>
                  <td>{s.step}</td>
                  <td className="settings-step-output">{s.output.slice(0, 200)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        <p className="muted settings-fallback">
          If the API container itself can't reach Docker (e.g. a locked-down or remote
          host), run the equivalent script manually from the project root instead:
        </p>
        <pre className="settings-code">
{`# Windows (PowerShell)
./scripts/recreate-sql-container.ps1

# macOS / Linux
./scripts/recreate-sql-container.sh`}
        </pre>
      </section>

      {message && <div className="hint settings-message">{message}</div>}
    </div>
  );
}
