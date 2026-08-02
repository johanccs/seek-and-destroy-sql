import { NavLink } from "react-router";
import { useTheme } from "../theme";

const cls = ({ isActive }: { isActive: boolean }) => `topnav-link ${isActive ? "active" : ""}`;

// The app's only global navigation: it switches curriculum *tracks*. The theme
// toggle and Settings live here rather than in a sidebar because both apply to
// every track.
export function TopNav() {
  const { theme, toggle } = useTheme();

  return (
    <header className="topnav">
      <div className="topnav-brand">⚔️ Seek &amp; Destroy</div>

      <nav className="topnav-tracks">
        <NavLink to="/perf" className={cls}>
          <span className="topnav-icon" aria-hidden="true">⚡</span>
          <span className="topnav-label">SQL Performance</span>
        </NavLink>
        <NavLink to="/design" className={cls}>
          <span className="topnav-icon" aria-hidden="true">🗂️</span>
          <span className="topnav-label">Database Design</span>
        </NavLink>
      </nav>

      <div className="topnav-actions">
        <NavLink to="/settings" className={cls} title="Settings" aria-label="Settings">
          ⚙
        </NavLink>
        <button
          className="theme-toggle"
          onClick={toggle}
          title="Toggle light/dark theme"
          aria-label="Toggle light/dark theme"
        >
          {theme === "dark" ? "☀️" : "🌙"}
        </button>
      </div>
    </header>
  );
}
