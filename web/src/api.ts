import type {
  ConcurrencyResult,
  InterleavingStep,
  LessonDetail,
  LevelGroup,
  ProgressSummary,
  RunResult,
} from "./types";

const BASE = (import.meta.env.VITE_API_BASE as string) || "http://localhost:5080";

async function json<T>(res: Response): Promise<T> {
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return (await res.json()) as T;
}

export const api = {
  health: () => fetch(`${BASE}/api/health`).then(json<{ status: string; sqlServer: string; lessonsLoaded: number }>),

  levels: () => fetch(`${BASE}/api/levels`).then(json<LevelGroup[]>),

  lesson: (id: string) => fetch(`${BASE}/api/lessons/${id}`).then(json<LessonDetail>),

  solution: (id: string) =>
    fetch(`${BASE}/api/lessons/${id}/solution`).then(json<{ solution: string }>),

  run: (id: string, sql: string) =>
    fetch(`${BASE}/api/lessons/${id}/run`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sql }),
    }).then(json<RunResult>),

  runConcurrency: (id: string, sessions: { A: InterleavingStep[]; B: InterleavingStep[] }) =>
    fetch(`${BASE}/api/lessons/${id}/run-concurrency`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sessions }),
    }).then(json<ConcurrencyResult>),

  reset: (id: string) =>
    fetch(`${BASE}/api/lessons/${id}/reset`, { method: "POST" }).then(
      json<{ status: string; database: string; elapsedMs: number }>,
    ),

  progress: () => fetch(`${BASE}/api/progress`).then(json<ProgressSummary>),

  settingsInfo: () =>
    fetch(`${BASE}/api/settings/info`).then(
      json<{ sqlServerHost: string; lessonsLoaded: number; progress: ProgressSummary }>,
    ),

  resetAllDatabases: () =>
    fetch(`${BASE}/api/settings/reset-all-databases`, { method: "POST" }).then(
      json<{ lessonsReset: number; failed: number; elapsedMs: number; failures: string[] }>,
    ),

  resetProgress: () =>
    fetch(`${BASE}/api/settings/reset-progress`, { method: "POST" }).then(
      json<{ rowsCleared: number }>,
    ),

  recreateSqlContainer: (keepData: boolean) =>
    fetch(`${BASE}/api/settings/recreate-sql-container`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ keepData }),
    }).then(
      json<{
        success: boolean;
        elapsedMs: number;
        steps: { step: string; success: boolean; output: string }[];
        reseed: { lessonsReset: number; failed: number; elapsedMs: number; failures: string[] } | null;
      }>,
    ),
};
