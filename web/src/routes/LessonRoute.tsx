import { useEffect, useState } from "react";
import { useOutletContext, useParams } from "react-router";
import type { LessonDetail } from "../types";
import { api } from "../api";
import { LessonView } from "../components/LessonView";
import type { PerfOutletContext } from "../layouts/PerfLayout";
import { useTheme } from "../theme";

export default function LessonRoute() {
  const { lessonId } = useParams<{ lessonId: string }>();
  const { refresh } = useOutletContext<PerfOutletContext>();
  const { theme } = useTheme();
  const [lesson, setLesson] = useState<LessonDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!lessonId) return;
    // Guard against out-of-order responses when the user clicks through the
    // list quickly: only the newest request may write state.
    let current = true;
    setLesson(null);
    setError(null);
    api
      .lesson(lessonId)
      .then((l) => current && setLesson(l))
      .catch((e) => current && setError(String(e)));
    return () => {
      current = false;
    };
  }, [lessonId]);

  if (error) {
    return (
      <div className="empty">
        <div className="hint" style={{ borderColor: "var(--bad)" }}>{error}</div>
      </div>
    );
  }
  if (!lesson) return <div className="empty">Loading lesson…</div>;

  return <LessonView lesson={lesson} onSolved={refresh} theme={theme} />;
}
