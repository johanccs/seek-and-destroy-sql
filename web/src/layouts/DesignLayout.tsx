import { Outlet } from "react-router-dom";

// Placeholder shell for the Database Design track. The module navigator and
// roadmap land with the design curriculum itself; this exists so the route and
// the top-nav entry are real from the start.
export default function DesignLayout() {
  return (
    <div className="app" style={{ "--sidebar-w": "300px" } as React.CSSProperties}>
      <aside className="sidebar">
        <div className="brand">
          <div className="sub">
            Database Design — model schemas on a canvas, then build them for real
          </div>
        </div>
      </aside>
      <main className="main">
        <Outlet />
      </main>
    </div>
  );
}
