import { useEffect, useState } from "react";

export const FONT_SIZE_STORAGE_PREFIX = "sqlperf-fontsize-";
const STORAGE_PREFIX = FONT_SIZE_STORAGE_PREFIX;

// A "reset all" click needs every mounted useFontSize instance (which may live in
// far-apart components — sidebar, editor, tutor, settings cards) to snap back to its
// own default in place, without a full page reload (which would also blow away
// unrelated app state like which view/lesson is open). A same-tab custom event does
// that; the native "storage" event only fires in *other* tabs.
const RESET_EVENT = "sqlperf-fontsize-reset-all";

export function resetAllFontSizes() {
  Object.keys(localStorage)
    .filter((k) => k.startsWith(STORAGE_PREFIX))
    .forEach((k) => localStorage.removeItem(k));
  window.dispatchEvent(new Event(RESET_EVENT));
}

/**
 * One panel's independent text-size setting, persisted in localStorage under
 * its own key so panels never share a size with each other.
 */
export function useFontSize(key: string, defaultSize: number, min = 10, max = 22) {
  const [size, setSize] = useState<number>(() => {
    const raw = Number(localStorage.getItem(STORAGE_PREFIX + key));
    return raw >= min && raw <= max ? raw : defaultSize;
  });

  useEffect(() => {
    localStorage.setItem(STORAGE_PREFIX + key, String(size));
  }, [key, size]);

  useEffect(() => {
    const onResetAll = () => setSize(defaultSize);
    window.addEventListener(RESET_EVENT, onResetAll);
    return () => window.removeEventListener(RESET_EVENT, onResetAll);
  }, [defaultSize]);

  return {
    size,
    min,
    max,
    increase: () => setSize((s) => Math.min(max, s + 1)),
    decrease: () => setSize((s) => Math.max(min, s - 1)),
  };
}

export type FontSizeState = ReturnType<typeof useFontSize>;

export function FontSizeControl({ label, fontSize }: { label: string; fontSize: FontSizeState }) {
  return (
    <div className="fontsize-control" role="group" aria-label={`${label} text size`}>
      <button
        type="button"
        className="fontsize-btn"
        onClick={fontSize.decrease}
        disabled={fontSize.size <= fontSize.min}
        title="Decrease text size"
        aria-label="Decrease text size"
      >
        A−
      </button>
      <span className="fontsize-value">{fontSize.size}px</span>
      <button
        type="button"
        className="fontsize-btn"
        onClick={fontSize.increase}
        disabled={fontSize.size >= fontSize.max}
        title="Increase text size"
        aria-label="Increase text size"
      >
        A+
      </button>
    </div>
  );
}
