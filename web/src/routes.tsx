import { lazy, Suspense } from "react";
import { createBrowserRouter, Navigate } from "react-router";
import RootLayout from "./layouts/RootLayout";
import PerfLayout from "./layouts/PerfLayout";
import DesignLayout from "./layouts/DesignLayout";
import PerfEmpty from "./routes/PerfEmpty";
import LessonRoute from "./routes/LessonRoute";
import DesignOverview from "./routes/DesignOverview";
const ModuleRoute = lazy(() => import("./routes/ModuleRoute"));
import { SettingsView } from "./components/SettingsView";
import { PrivacyView } from "./components/PrivacyView";
import { TermsView } from "./components/TermsView";

// Deep links need a server-side SPA fallback: see web/nginx.conf (Docker) and
// web/staticwebapp.config.json (Azure Static Web Apps).
export const router = createBrowserRouter([
  {
    path: "/",
    element: <RootLayout />,
    children: [
      { index: true, element: <Navigate to="/perf" replace /> },
      {
        path: "perf",
        element: <PerfLayout />,
        children: [
          { index: true, element: <PerfEmpty /> },
          { path: "lessons/:lessonId", element: <LessonRoute /> },
        ],
      },
      {
        path: "design",
        element: <DesignLayout />,
        children: [
          { index: true, element: <DesignOverview /> },
          {
            path: "modules/:moduleId",
            // Lazily loaded so the performance track never pays for React Flow.
            element: (
              <Suspense fallback={<div className="empty">Loading canvas…</div>}>
                <ModuleRoute />
              </Suspense>
            ),
          },
        ],
      },
      { path: "settings", element: <SettingsView /> },
      { path: "privacy", element: <PrivacyView /> },
      { path: "terms", element: <TermsView /> },
      { path: "*", element: <Navigate to="/perf" replace /> },
    ],
  },
]);
