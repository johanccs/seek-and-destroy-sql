import { createBrowserRouter, Navigate } from "react-router-dom";
import RootLayout from "./layouts/RootLayout";
import PerfLayout from "./layouts/PerfLayout";
import DesignLayout from "./layouts/DesignLayout";
import PerfEmpty from "./routes/PerfEmpty";
import LessonRoute from "./routes/LessonRoute";
import DesignOverview from "./routes/DesignOverview";
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
        children: [{ index: true, element: <DesignOverview /> }],
      },
      { path: "settings", element: <SettingsView /> },
      { path: "privacy", element: <PrivacyView /> },
      { path: "terms", element: <TermsView /> },
      { path: "*", element: <Navigate to="/perf" replace /> },
    ],
  },
], {
  // Opt in early to the v7 behaviours so the console stays clean and the
  // eventual upgrade is a version bump rather than a behaviour change.
  // v7_startTransition is a RouterProvider flag, not a router one — see main.tsx.
  future: { v7_relativeSplatPath: true },
});
