// Lightweight difficulty signal, purely derived on the client from a lesson's own
// estimated time -- no backend/manifest changes needed. Buckets estimatedMinutes into
// a 1-5 star rating so the navigator shows more than just the beginner/intermediate/
// advanced/expert level.
export function difficultyStars(estimatedMinutes: number): number {
  if (estimatedMinutes < 10) return 1;
  if (estimatedMinutes < 14) return 2;
  if (estimatedMinutes < 18) return 3;
  if (estimatedMinutes < 22) return 4;
  return 5;
}

export function difficultyLabel(estimatedMinutes: number): string {
  const n = difficultyStars(estimatedMinutes);
  return "★".repeat(n) + "☆".repeat(5 - n);
}
