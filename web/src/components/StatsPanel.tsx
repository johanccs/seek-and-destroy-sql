import type { RunStats } from "../types";

function Delta({ cur, prev }: { cur: number; prev: number | undefined }) {
  if (prev == null || prev === cur) return null;
  const diff = cur - prev;
  const down = diff < 0;
  const pct = prev !== 0 ? Math.round((Math.abs(diff) / prev) * 100) : 0;
  return (
    <div className={`delta ${down ? "down" : "up"}`}>
      {down ? "▼" : "▲"} {Math.abs(diff).toLocaleString()} ({pct}%)
    </div>
  );
}

export function StatsPanel({ stats, prev }: { stats: RunStats | null; prev: RunStats | null }) {
  if (!stats) return <div className="muted">Run a query to see statistics.</div>;
  const cards: { k: string; v: number; p?: number }[] = [
    { k: "Logical reads", v: stats.totalLogicalReads, p: prev?.totalLogicalReads },
    { k: "Physical reads", v: stats.totalPhysicalReads, p: prev?.totalPhysicalReads },
    { k: "CPU time (ms)", v: stats.cpuTimeMs, p: prev?.cpuTimeMs },
    { k: "Elapsed (ms)", v: stats.elapsedTimeMs, p: prev?.elapsedTimeMs },
    { k: "Rows affected", v: stats.rowsAffected, p: prev?.rowsAffected },
  ];
  return (
    <div>
      <div className="cards">
        {cards.map((c) => (
          <div className="card" key={c.k}>
            <div className="k">{c.k}</div>
            <div className="v">{c.v.toLocaleString()}</div>
            <Delta cur={c.v} prev={c.p} />
          </div>
        ))}
      </div>
      {stats.perTable.length > 0 && (
        <table className="grid">
          <thead>
            <tr>
              <th>Table</th>
              <th>Scan count</th>
              <th>Logical reads</th>
              <th>Physical reads</th>
            </tr>
          </thead>
          <tbody>
            {stats.perTable.map((t) => (
              <tr key={t.table}>
                <td>{t.table}</td>
                <td>{t.scanCount}</td>
                <td>{t.logicalReads.toLocaleString()}</td>
                <td>{t.physicalReads.toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
