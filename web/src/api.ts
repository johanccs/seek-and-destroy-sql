import type {
  ConcurrencyResult,
  InterleavingStep,
  LessonDetail,
  LevelGroup,
  ProgressSummary,
  RunResult,
  TutorMessage,
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

  settingsCapabilities: () =>
    fetch(`${BASE}/api/settings/capabilities`).then(json<{ recreateSqlContainer: boolean }>),

  resetAllDatabases: () =>
    fetch(`${BASE}/api/settings/reset-all-databases`, { method: "POST" }).then(
      json<{ lessonsReset: number; failed: number; elapsedMs: number; failures: string[] }>,
    ),

  resetProgress: () =>
    fetch(`${BASE}/api/settings/reset-progress`, { method: "POST" }).then(
      json<{ rowsCleared: number }>,
    ),

  tutorStatus: () => fetch(`${BASE}/api/tutor/status`).then(json<{ configured: boolean }>),

  tutorHistory: (lessonId: string) =>
    fetch(`${BASE}/api/lessons/${lessonId}/tutor/history`).then(json<TutorMessage[]>),

  tutorReset: (lessonId: string) =>
    fetch(`${BASE}/api/lessons/${lessonId}/tutor/reset`, { method: "POST" }),

  // Streams an assistant reply via SSE. Calls onDelta for each text chunk and
  // onCost once OpenRouter reports token usage for the finished message.
  tutorChat: async (
    lessonId: string,
    message: string,
    onDelta: (text: string) => void,
    onCost: (costZar: number | null) => void,
    signal?: AbortSignal,
  ) => {
    const res = await fetch(`${BASE}/api/lessons/${lessonId}/tutor/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message }),
      signal,
    });
    if (!res.ok || !res.body) throw new Error(`${res.status} ${res.statusText}`);

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buf = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += decoder.decode(value, { stream: true });
      const parts = buf.split("\n\n");
      buf = parts.pop() ?? "";
      for (const part of parts) {
        const line = part.trim();
        if (!line.startsWith("data:")) continue;
        const data = line.slice("data:".length).trim();
        if (data === "[DONE]") return;
        const evt = JSON.parse(data) as { delta?: string; costZar?: number | null; error?: string };
        if (evt.error) throw new Error(evt.error);
        if (evt.delta) onDelta(evt.delta);
        if (evt.costZar !== undefined) onCost(evt.costZar);
      }
    }
  },

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
