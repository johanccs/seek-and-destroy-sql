type Props = {
  axis: "col" | "row";
  onResizeStart: (e: React.MouseEvent) => void;
  collapsed: boolean;
  onToggle: () => void;
  /** What the pane is, for the tooltip: "lesson list", "DDL pane", … */
  label: string;
  /** Which way the pane lies from the handle. Decides the chevron direction. */
  side?: "before" | "after";
  className?: string;
};

const CHEVRON = {
  col: { before: { open: "‹", closed: "›" }, after: { open: "›", closed: "‹" } },
  row: { before: { open: "⌃", closed: "⌄" }, after: { open: "⌄", closed: "⌃" } },
};

/**
 * A drag strip plus a collapse toggle.
 *
 * It must live OUTSIDE the pane it controls — a handle nested in a collapsed
 * pane disappears with it, and then there is no way back.
 */
export function ResizeHandle({
  axis, onResizeStart, collapsed, onToggle, label, side = "before", className = "",
}: Props) {
  const chevron = CHEVRON[axis][side][collapsed ? "closed" : "open"];
  return (
    <div
      className={`rz rz-${axis} ${collapsed ? "collapsed" : ""} ${className}`}
      onMouseDown={onResizeStart}
      title={collapsed ? `Show the ${label}` : `Drag to resize the ${label}`}
    >
      <button
        className="rz-toggle"
        // Without this the click also starts a drag on the strip behind it.
        onMouseDown={(e) => e.stopPropagation()}
        onClick={onToggle}
        aria-label={collapsed ? `Show the ${label}` : `Hide the ${label}`}
        title={collapsed ? `Show the ${label}` : `Hide the ${label}`}
      >
        {chevron}
      </button>
    </div>
  );
}
