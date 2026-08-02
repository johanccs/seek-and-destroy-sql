import { useCallback, useEffect, useRef, useState } from "react";

type Opts = {
  storageKey: string;
  defaultWidth: number;
  /** Smallest useful size for the resized pane. */
  min: number;
  /** Largest size the user may drag to, when there is room for it. */
  max: number;
  /** Space the *other* pane must always keep; the resized one yields to it. */
  minRight: number;
  containerRef: React.RefObject<HTMLElement | null>;
  /**
   * "x" (default) sizes a left column, measured from the container's left edge.
   * "x-right" sizes a RIGHT column, measured from the container's right edge.
   * "y" sizes a BOTTOM pane, measured from the container's bottom edge — dragging
   * the handle upward makes it taller.
   */
  axis?: "x" | "x-right" | "y";
};

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

/**
 * Drives a draggable fixed-px left column in a two-track grid.
 *
 * Keeps the width the user *asked for* separate from the width that currently
 * fits: the desired width persists untouched, while the rendered width is
 * re-derived from the container's size. That way shrinking the browser borrows
 * space from the left column instead of shoving the right one off-screen, and
 * widening it again restores the user's original choice.
 */
export function useColumnResize({ storageKey, defaultWidth, min, max, minRight, containerRef, axis = "x" }: Opts) {
  const desired = useRef<number>(
    (() => {
      const saved = Number(localStorage.getItem(storageKey));
      return saved >= min && saved <= max ? saved : defaultWidth;
    })(),
  );
  const [width, setWidth] = useState(desired.current);
  const dragging = useRef(false);

  // Widest the left column may be while still leaving `minRight` on the right.
  const fit = useCallback(
    (w: number) => {
      const el = containerRef.current;
      const box = (axis === "y" ? el?.clientHeight : el?.clientWidth) ?? 0;
      const cap = box > 0 ? Math.max(min, box - minRight) : max;
      return clamp(w, min, Math.min(max, cap));
    },
    [containerRef, min, max, minRight, axis],
  );

  const reflow = useCallback(() => setWidth(fit(desired.current)), [fit]);

  // Re-clamp whenever the container resizes (window resize, sidebar drag, zoom).
  //
  // The container may not exist yet: a consumer that renders a loading state
  // first mounts this hook before the element. Waiting for it matters — without
  // the observer the clamp never runs, so a persisted size can exceed what now
  // fits and the pane overlaps its neighbour.
  useEffect(() => {
    let ro: ResizeObserver | undefined;
    let raf = 0;
    let usingWindow = false;

    const attach = () => {
      const el = containerRef.current;
      if (!el) {
        raf = requestAnimationFrame(attach);
        return;
      }
      reflow();
      if (typeof ResizeObserver === "undefined") {
        usingWindow = true;
        window.addEventListener("resize", reflow);
        return;
      }
      ro = new ResizeObserver(reflow);
      ro.observe(el);
    };
    attach();

    return () => {
      cancelAnimationFrame(raf);
      ro?.disconnect();
      if (usingWindow) window.removeEventListener("resize", reflow);
    };
  }, [reflow, containerRef]);

  const onResizeStart = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    dragging.current = true;
    document.body.style.cursor = axis === "y" ? "row-resize" : "col-resize";
    document.body.style.userSelect = "none";
  }, [axis]);

  useEffect(() => {
    const onMove = (e: MouseEvent) => {
      if (!dragging.current) return;
      const box = containerRef.current?.getBoundingClientRect();
      // A "y" pane is anchored to the bottom, so its size grows as the pointer
      // moves up: measure from the container's bottom edge, not its top.
      const raw =
        axis === "y" ? (box?.bottom ?? 0) - e.clientY
        // "x-right" is anchored to the right edge, so it grows as the pointer
        // moves left — the mirror of the default left-anchored column.
        : axis === "x-right" ? (box?.right ?? 0) - e.clientX
        : e.clientX - (box?.left ?? 0);
      desired.current = clamp(raw, min, max);
      setWidth(fit(desired.current));
    };
    const onUp = () => {
      if (!dragging.current) return;
      dragging.current = false;
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
      localStorage.setItem(storageKey, String(desired.current));
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
  }, [containerRef, fit, min, max, storageKey, axis]);

  return { width, onResizeStart };
}
