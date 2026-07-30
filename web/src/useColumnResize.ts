import { useCallback, useEffect, useRef, useState } from "react";

type Opts = {
  storageKey: string;
  defaultWidth: number;
  /** Smallest useful width for the left column. */
  min: number;
  /** Largest width the user may drag to, when there is room for it. */
  max: number;
  /** Space the right column must always keep; the left column yields to it. */
  minRight: number;
  containerRef: React.RefObject<HTMLElement | null>;
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
export function useColumnResize({ storageKey, defaultWidth, min, max, minRight, containerRef }: Opts) {
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
      const box = containerRef.current?.clientWidth ?? 0;
      const cap = box > 0 ? Math.max(min, box - minRight) : max;
      return clamp(w, min, Math.min(max, cap));
    },
    [containerRef, min, max, minRight],
  );

  const reflow = useCallback(() => setWidth(fit(desired.current)), [fit]);

  // Re-clamp whenever the container resizes (window resize, sidebar drag, zoom).
  useEffect(() => {
    reflow();
    const el = containerRef.current;
    if (!el || typeof ResizeObserver === "undefined") {
      window.addEventListener("resize", reflow);
      return () => window.removeEventListener("resize", reflow);
    }
    const ro = new ResizeObserver(reflow);
    ro.observe(el);
    return () => ro.disconnect();
  }, [reflow, containerRef]);

  const onResizeStart = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    dragging.current = true;
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
  }, []);

  useEffect(() => {
    const onMove = (e: MouseEvent) => {
      if (!dragging.current) return;
      const left = containerRef.current?.getBoundingClientRect().left ?? 0;
      desired.current = clamp(e.clientX - left, min, max);
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
  }, [containerRef, fit, min, max, storageKey]);

  return { width, onResizeStart };
}
