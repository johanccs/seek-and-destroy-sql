/**
 * The app mark: Lucide's `database` icon (ISC), inlined rather than pulled in as
 * a dependency — it is one path, and the licence allows it.
 *
 * Drawn on a 24px grid, which is why it stays legible down to ~11px where the
 * hand-drawn alternatives turned to mush. The favicon uses the filled variant
 * (web/public/favicon.svg): outline reads well at nav size, a solid silhouette
 * reads better in a browser tab.
 */
export function Logo({ size = 17 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <ellipse cx="12" cy="5" rx="9" ry="3" />
      <path d="M3 5v14a9 3 0 0 0 18 0V5" />
      <path d="M3 12a9 3 0 0 0 18 0" />
    </svg>
  );
}
