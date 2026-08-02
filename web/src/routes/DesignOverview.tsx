import { Link } from "react-router-dom";
import { ROADMAP } from "../design/roadmap";
import { useCurriculum } from "../hooks/useCurriculum";

export default function DesignOverview() {
  const { levels } = useCurriculum("design");
  const solved = new Set(
    levels.flatMap((g) => g.lessons.filter((l) => l.solved).map((l) => l.id)),
  );
  const built = ROADMAP.flatMap((l) => l.entries).filter((e) => e.id).length;
  const total = ROADMAP.flatMap((l) => l.entries).length;

  return (
    <div className="roadmap">
      <h2>Database Design</h2>
      <p className="muted roadmap-intro">
        Model schemas on an interactive canvas, then build them for real against a live SQL Server.
        Every module is graded by reading the schema your DDL actually created — so a diagram that
        wouldn’t build can’t pass, and writing the SQL by hand instead passes just the same.
      </p>

      <div className="hint roadmap-status">
        <strong>{built} of {total} modules built.</strong> The rest of the curriculum is listed below
        so you can see where each one sits in the arc. Unbuilt modules aren’t clickable — they’re the
        plan, not a promise that they’re finished.
      </div>

      {ROADMAP.map((level) => (
        <section className="roadmap-level" key={level.level}>
          <div className="level-title">
            <span>{level.title}</span>
            <span>{level.widget}</span>
          </div>
          <ol className="roadmap-list">
            {level.entries.map((e) => {
              const isBuilt = !!e.id;
              const isSolved = e.id ? solved.has(e.id) : false;
              const body = (
                <>
                  <span className="roadmap-n">{e.n}</span>
                  <span className="roadmap-text">
                    <span className="roadmap-title">
                      {e.title}
                      {isSolved && <span className="roadmap-tick"> ✓</span>}
                    </span>
                    <span className="roadmap-blurb">{e.blurb}</span>
                  </span>
                  {!isBuilt && <span className="roadmap-soon">soon</span>}
                </>
              );
              return isBuilt ? (
                <li className="roadmap-item built" key={e.n}>
                  <Link to={`/design/modules/${e.id}`}>{body}</Link>
                </li>
              ) : (
                <li className="roadmap-item" key={e.n} aria-disabled="true">
                  {body}
                </li>
              );
            })}
          </ol>
        </section>
      ))}
    </div>
  );
}
