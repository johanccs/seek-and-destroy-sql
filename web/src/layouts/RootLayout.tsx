import { NavLink, Outlet } from "react-router";
import { TopNav } from "../components/TopNav";
import { ThemeProvider } from "../theme";

// The page shell: top nav, the active track's own layout, and the global footer.
// The three-row grid lives here so `.app` keeps its own two-column layout
// untouched — the minmax(0,1fr) in that grid is load-bearing.
export default function RootLayout() {
  return (
    <ThemeProvider>
      <div className="shell">
        <TopNav />
        <Outlet />
        <footer className="site-footer">
          <span className="footer-copyright">© 2026 CCS</span>
          <nav className="footer-links">
            <NavLink to="/privacy" className={({ isActive }) => `footer-link ${isActive ? "active" : ""}`}>
              Privacy
            </NavLink>
            <NavLink to="/terms" className={({ isActive }) => `footer-link ${isActive ? "active" : ""}`}>
              Terms
            </NavLink>
            <a href="https://github.com/johanccs/seek-and-destroy-sql" target="_blank" rel="noopener">
              GitHub
            </a>
          </nav>
          <span className="footer-badge">Built with React + ASP.NET Core</span>
        </footer>
      </div>
    </ThemeProvider>
  );
}
