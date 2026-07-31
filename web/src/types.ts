// Mirrors docs/CONTRACT.md section 3. Keep in sync with the API DTOs.

export type Level = "beginner" | "intermediate" | "advanced" | "expert";

export interface LessonProgress {
  solved: boolean;
  bestLogicalReads: number | null;
  bestDurationMs: number | null;
  newlySolved?: boolean;
}

export interface LessonSummary {
  id: string;
  order: number;
  title: string;
  description: string;
  topics: string[];
  estimatedMinutes: number;
  isConcurrency: boolean;
  solved: boolean;
  bestLogicalReads: number | null;
  bestDurationMs: number | null;
  azureUnsupported: boolean;
}

export interface LevelGroup {
  level: Level;
  title: string;
  description: string;
  lessons: LessonSummary[];
}

export interface InterleavingStep {
  sql: string;
  afterMs: number;
}

export interface Interleaving {
  description: string;
  sessions: { A: InterleavingStep[]; B: InterleavingStep[] };
  resolveConditions?: ConditionResult[];
}

export interface LessonDetail {
  id: string;
  level: Level;
  title: string;
  description: string;
  topics: string[];
  estimatedMinutes: number;
  narrative: string;
  startingQuery: string;
  hints: string[];
  isConcurrency: boolean;
  interleaving: Interleaving | null;
  progress: LessonProgress;
  azureUnsupported: boolean;
}

export interface PlanNode {
  nodeId: number;
  physicalOp: string;
  logicalOp: string;
  estimateRows: number;
  actualRows: number | null;
  estimatedCostPercent: number;
  object: string | null;
  warnings: string[];
  children: PlanNode[];
}

export interface PlanWarning {
  type: string;
  impact: number;
  detail: string;
}

export interface MissingIndex {
  impact: number;
  statement: string;
}

export interface QueryPlan {
  root: PlanNode | null;
  warnings: PlanWarning[];
  missingIndexes: MissingIndex[];
}

export interface PerTableStat {
  table: string;
  logicalReads: number;
  physicalReads: number;
  scanCount: number;
}

export interface RunStats {
  totalLogicalReads: number;
  totalPhysicalReads: number;
  cpuTimeMs: number;
  elapsedTimeMs: number;
  rowsAffected: number;
  perTable: PerTableStat[];
}

export interface ResultSet {
  columns: string[];
  rows: (string | number | null)[][];
  rowCount: number;
  truncated: boolean;
}

export interface ConditionResult {
  type: string;
  label: string;
  passed: boolean;
  detail: string;
}

export interface Evaluation {
  passed: boolean;
  conditions: ConditionResult[];
}

export interface RunResult {
  success: boolean;
  error: string | null;
  resultSets: ResultSet[];
  stats: RunStats | null;
  plan: QueryPlan | null;
  messages: string[];
  evaluation: Evaluation | null;
  progress: LessonProgress | null;
}

export interface TimelineEvent {
  tMs: number;
  session: "A" | "B";
  event: string;
  detail: string;
}

export interface ConcurrencyResult {
  outcome: "completed" | "deadlock" | "blocked-timeout" | "error";
  deadlockVictim: "A" | "B" | null;
  timeline: TimelineEvent[];
  deadlockGraphXml: string | null;
  evaluation: Evaluation | null;
  progress: LessonProgress | null;
}

export interface TutorMessage {
  role: "user" | "assistant";
  content: string;
  ts: number;
  costZar?: number | null;
}

export interface ProgressSummary {
  totalLessons: number;
  solvedLessons: number;
  byLevel: { level: Level; total: number; solved: number }[];
}

export type SchemaColumn = {
  name: string; dataType: string; nullable: boolean; isIdentity: boolean; inPrimaryKey: boolean;
};
export type SchemaIndex = {
  name: string; type: string; isUnique: boolean; isPrimaryKey: boolean;
  keyColumns: string; includedColumns: string; filter: string | null;
};
export type SchemaTable = {
  name: string; rowCount: number; columns: SchemaColumn[]; indexes: SchemaIndex[];
};
export type SchemaInfo = { schema: string; seeded: boolean; tables: SchemaTable[] };
