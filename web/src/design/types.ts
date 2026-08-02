// The canvas domain model. Mirrors api/SqlPerf.Api/Models/ErdModel.cs.
//
// Deliberately independent of React Flow: the DDL generator, the grader and the
// saved-diagram store all speak this shape, and toFlow/fromFlow are the only
// places that know a rendering library exists. Swapping the canvas out means
// rewriting one adapter, not the feature.

export type Cardinality = "manyToOne" | "oneToOne" | "manyToMany";
export type ReferentialAction = "NO ACTION" | "CASCADE" | "SET NULL";

export type ErdAttribute = {
  name: string;
  dataType: string;
  nullable?: boolean;
  isPrimaryKey?: boolean;
  isIdentity?: boolean;
  /** Unique, but not the identifier — emitted as a UNIQUE constraint. */
  isUnique?: boolean;
  /** A DEFAULT expression: a literal, or one of a few allowed functions. */
  defaultValue?: string;
};

/**
 * A CHECK, expressed as three constrained parts rather than free text — a CHECK
 * is arbitrary SQL reaching the engine, and an expression cannot be validated
 * the way an identifier can.
 */
export type ErdCheck = {
  column: string;
  operator: "=" | "<>" | ">" | ">=" | "<" | "<=" | "IN" | "BETWEEN" | "LIKE";
  value: string;
};

export type ErdEntity = {
  id: string;
  name: string;
  x: number;
  y: number;
  attributes: ErdAttribute[];
  checks?: ErdCheck[];
};

export type ErdRelationship = {
  id: string;
  /** The child — the side that carries the foreign key. */
  fromEntityId: string;
  /** The parent — the side being referenced. */
  toEntityId: string;
  fromColumns: string[];
  toColumns: string[];
  cardinality: Cardinality;
  onDelete: ReferentialAction;
};

export type ErdModel = {
  entities: ErdEntity[];
  relationships: ErdRelationship[];
};

export type ModuleStep = { kind: "read" | "canvas" | "sql"; prompt?: string; anchor?: string };

export type ModuleDetail = {
  id: string;
  track: string;
  kind: string;
  level: string;
  title: string;
  description: string;
  topics: string[];
  estimatedMinutes: number;
  narrative: string;
  hints: string[];
  steps: ModuleStep[];
  startingModel: ErdModel | null;
  progress: { solved: boolean; newlySolved?: boolean };
  azureUnsupported: boolean;
};

export type DdlResponse = { ddl: string; warnings: string[] };

export type CheckResult = {
  success: boolean;
  error: string | null;
  ddl: string;
  warnings: string[];
  schema: import("../types").SchemaInfo | null;
  evaluation: import("../types").Evaluation | null;
  progress: { solved: boolean; newlySolved?: boolean } | null;
};

export const emptyModel = (): ErdModel => ({ entities: [], relationships: [] });

// Types offered in the inspector. Kept in step with DdlGenerator's allowlist —
// anything outside it is rejected server-side rather than escaped.
// Kept in step with DdlGenerator.DefaultFunctions.
export const DEFAULT_FUNCTIONS = ["SYSUTCDATETIME()", "GETUTCDATE()", "SYSDATETIME()", "GETDATE()", "NEWID()"];
export const CHECK_OPERATORS = ["=", "<>", ">", ">=", "<", "<=", "IN", "BETWEEN", "LIKE"] as const;

export const DATA_TYPES = [
  "int", "bigint", "smallint", "tinyint", "bit",
  "decimal(10,2)", "money", "float",
  "date", "datetime2", "time",
  "nvarchar(50)", "nvarchar(100)", "nvarchar(200)", "nvarchar(max)",
  "varchar(50)", "varchar(100)",
  "uniqueidentifier",
];
