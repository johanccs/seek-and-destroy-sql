import { useEffect, useState } from "react";

const STORAGE_PREFIX = "sqlperf-fontsize-";

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
