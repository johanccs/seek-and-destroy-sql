import type { ErdAttribute, ErdEntity, ErdModel, ErdRelationship } from "./types";

// ---------------------------------------------------------------------------
// Edits
// ---------------------------------------------------------------------------

export type ErdAction =
  | { t: "load"; model: ErdModel }
  | { t: "addEntity"; x: number; y: number }
  | { t: "renameEntity"; id: string; name: string }
  | { t: "moveEntity"; id: string; x: number; y: number }
  | { t: "deleteEntity"; id: string }
  | { t: "addAttribute"; entityId: string }
  | { t: "updateAttribute"; entityId: string; index: number; patch: Partial<ErdAttribute> }
  | { t: "deleteAttribute"; entityId: string; index: number }
  | { t: "connect"; fromEntityId: string; toEntityId: string; column?: string }
  | { t: "updateRelationship"; id: string; patch: Partial<ErdRelationship> }
  | { t: "deleteRelationship"; id: string };

const uid = (p: string) => `${p}-${Math.random().toString(36).slice(2, 9)}`;

// Moves are excluded from undo history: dragging a node emits a change per
// frame, and recording each one would make Ctrl+Z rewind a drag pixel by pixel.
export const isTransient = (a: ErdAction) => a.t === "moveEntity";

function uniqueName(model: ErdModel, base: string) {
  let n = base;
  let i = 2;
  while (model.entities.some((e) => e.name.toLowerCase() === n.toLowerCase())) n = `${base}${i++}`;
  return n;
}

export function reduce(model: ErdModel, a: ErdAction): ErdModel {
  switch (a.t) {
    case "load":
      return a.model;

    case "addEntity": {
      const name = uniqueName(model, "NewTable");
      const entity: ErdEntity = {
        id: uid("e"),
        name,
        x: a.x,
        y: a.y,
        // A surrogate key by default — it is the common case, and starting with
        // no key at all makes the first generated DDL fail for a reason that has
        // nothing to do with what the learner is being taught.
        attributes: [{ name: `${name}Id`, dataType: "int", isPrimaryKey: true, isIdentity: true }],
      };
      return { ...model, entities: [...model.entities, entity] };
    }

    case "renameEntity":
      return {
        ...model,
        entities: model.entities.map((e) => (e.id === a.id ? { ...e, name: a.name } : e)),
      };

    case "moveEntity":
      return {
        ...model,
        entities: model.entities.map((e) => (e.id === a.id ? { ...e, x: a.x, y: a.y } : e)),
      };

    case "deleteEntity":
      return {
        entities: model.entities.filter((e) => e.id !== a.id),
        // Relationships to a deleted table would dangle, so they go too.
        relationships: model.relationships.filter(
          (r) => r.fromEntityId !== a.id && r.toEntityId !== a.id,
        ),
      };

    case "addAttribute":
      return {
        ...model,
        entities: model.entities.map((e) =>
          e.id === a.entityId
            ? { ...e, attributes: [...e.attributes, { name: `Column${e.attributes.length + 1}`, dataType: "int" }] }
            : e,
        ),
      };

    case "updateAttribute":
      return {
        ...model,
        entities: model.entities.map((e) =>
          e.id === a.entityId
            ? {
                ...e,
                attributes: e.attributes.map((at, i) => (i === a.index ? { ...at, ...a.patch } : at)),
              }
            : e,
        ),
      };

    case "deleteAttribute":
      return {
        ...model,
        entities: model.entities.map((e) =>
          e.id === a.entityId ? { ...e, attributes: e.attributes.filter((_, i) => i !== a.index) } : e,
        ),
      };

    case "connect": {
      if (a.fromEntityId === a.toEntityId) return model; // self-references need explicit columns
      const parent = model.entities.find((e) => e.id === a.toEntityId);
      const child = model.entities.find((e) => e.id === a.fromEntityId);
      if (!parent || !child) return model;

      const parentKey = parent.attributes.filter((x) => x.isPrimaryKey);
      if (parentKey.length === 0) return model; // nothing to point at yet

      // Reuse a matching column on the child if one already exists, otherwise
      // add it — the learner drew the relationship, so the key is implied.
      const wanted = a.column ?? parentKey[0].name;
      const existing = child.attributes.find((x) => x.name.toLowerCase() === wanted.toLowerCase());
      const entities = existing
        ? model.entities
        : model.entities.map((e) =>
            e.id === child.id
              ? {
                  ...e,
                  attributes: [
                    ...e.attributes,
                    { name: wanted, dataType: parentKey[0].dataType, nullable: false },
                  ],
                }
              : e,
          );

      const rel: ErdRelationship = {
        id: uid("r"),
        fromEntityId: child.id,
        toEntityId: parent.id,
        fromColumns: [wanted],
        toColumns: [parentKey[0].name],
        cardinality: "manyToOne",
        onDelete: "NO ACTION",
      };
      const dup = model.relationships.some(
        (r) => r.fromEntityId === rel.fromEntityId && r.toEntityId === rel.toEntityId,
      );
      return { entities, relationships: dup ? model.relationships : [...model.relationships, rel] };
    }

    case "updateRelationship":
      return {
        ...model,
        relationships: model.relationships.map((r) => (r.id === a.id ? { ...r, ...a.patch } : r)),
      };

    case "deleteRelationship":
      return { ...model, relationships: model.relationships.filter((r) => r.id !== a.id) };
  }
}

// ---------------------------------------------------------------------------
// Undo / redo
// ---------------------------------------------------------------------------

export type History = { past: ErdModel[]; present: ErdModel; future: ErdModel[] };

const LIMIT = 50;

export function apply(h: History, a: ErdAction): History {
  const next = reduce(h.present, a);
  if (next === h.present) return h;
  if (a.t === "load") return { past: [], present: next, future: [] };
  if (isTransient(a)) return { ...h, present: next };
  return { past: [...h.past, h.present].slice(-LIMIT), present: next, future: [] };
}

export function undo(h: History): History {
  if (h.past.length === 0) return h;
  const previous = h.past[h.past.length - 1];
  return { past: h.past.slice(0, -1), present: previous, future: [h.present, ...h.future] };
}

export function redo(h: History): History {
  if (h.future.length === 0) return h;
  const [next, ...rest] = h.future;
  return { past: [...h.past, h.present], present: next, future: rest };
}
