import { useCallback, useEffect, useState } from "react";
import type { LevelGroup, ProgressSummary } from "../types";
import { api } from "../api";

// The levels + progress fetch that used to live in App.tsx. Two call sites
// (the perf sidebar and SettingsView's onChanged) don't justify a context.
export function useCurriculum(track?: string) {
  const [levels, setLevels] = useState<LevelGroup[]>([]);
  const [progress, setProgress] = useState<ProgressSummary | null>(null);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const [lv, pr] = await Promise.all([api.levels(track), api.progress(track)]);
      setLevels(lv);
      setProgress(pr);
      setError(null);
    } catch (e) {
      // On the hosted site this is usually a cold B1 App Service still waking up
      // rather than a real outage, so say so before blaming the user's setup.
      setError(
        `Cannot reach the API yet. On the hosted site it runs on an Azure B1 Basic plan and can take a few seconds to wake — give it a moment and refresh. Running locally? Check the API container is up. (${e})`,
      );
    }
  }, [track]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { levels, progress, error, refresh };
}
