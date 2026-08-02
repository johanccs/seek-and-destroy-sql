export default function PerfEmpty() {
  return (
    <div className="empty">
      <div>
        <h2>Select a lesson to begin</h2>
        <p className="muted">
          Work from Beginner to Expert. Each lesson runs real SQL and grades your fix automatically.
        </p>
        <p className="muted startup-note">
          ⏳ <strong>First load and first run can be slow.</strong> The hosted API runs on a
          modest Azure App Service <strong>B1 Basic</strong> plan, so it takes a moment to wake
          up and warm its connection pool, and some lessons seed large tables — up to 1.2 million
          rows — the first time you open them. Later runs are much quicker. Running it locally
          with Docker avoids the wait entirely.
        </p>
      </div>
    </div>
  );
}
