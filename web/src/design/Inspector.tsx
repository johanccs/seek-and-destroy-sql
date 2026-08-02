import type { ErdModel, Cardinality, ReferentialAction } from "./types";
import { DATA_TYPES } from "./types";
import type { ErdAction } from "./model";

export type Selection = { kind: "entity" | "relationship"; id: string } | null;

// Properties for whatever is selected — reachable by clicking or right-clicking
// an object on the canvas. Nothing here is cosmetic: every field maps to
// something the generated DDL emits.
export function Inspector({
  model,
  selection,
  dispatch,
}: {
  model: ErdModel;
  selection: Selection;
  dispatch: (a: ErdAction) => void;
}) {
  if (!selection) {
    return (
      <div className="erd-inspector">
        <div className="props-sub">Properties</div>
        <p className="muted">
          Select a table or a relationship to edit it. Right-click works too.
        </p>
      </div>
    );
  }

  if (selection.kind === "entity") {
    const e = model.entities.find((x) => x.id === selection.id);
    if (!e) return <div className="erd-inspector" />;
    return (
      <div className="erd-inspector">
        <div className="props-sub">Table</div>
        <input
          className="erd-input"
          value={e.name}
          onChange={(ev) => dispatch({ t: "renameEntity", id: e.id, name: ev.target.value })}
          aria-label="Table name"
        />

        <div className="props-sub">Columns</div>
        {e.attributes.map((a, i) => (
          <div className="erd-attr-edit" key={i}>
            <input
              className="erd-input"
              value={a.name}
              onChange={(ev) =>
                dispatch({ t: "updateAttribute", entityId: e.id, index: i, patch: { name: ev.target.value } })
              }
              aria-label="Column name"
            />
            <select
              className="erd-input"
              value={a.dataType}
              onChange={(ev) =>
                dispatch({ t: "updateAttribute", entityId: e.id, index: i, patch: { dataType: ev.target.value } })
              }
              aria-label="Data type"
            >
              {DATA_TYPES.includes(a.dataType) ? null : <option value={a.dataType}>{a.dataType}</option>}
              {DATA_TYPES.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
            <label className="erd-flag">
              <input
                type="checkbox"
                checked={!!a.isPrimaryKey}
                onChange={(ev) =>
                  dispatch({
                    t: "updateAttribute",
                    entityId: e.id,
                    index: i,
                    // A key column cannot be nullable, so setting PK clears it
                    // rather than letting the DDL fail later.
                    patch: { isPrimaryKey: ev.target.checked, nullable: ev.target.checked ? false : a.nullable },
                  })
                }
              />
              PK
            </label>
            <label className="erd-flag">
              <input
                type="checkbox"
                checked={!!a.isIdentity}
                onChange={(ev) =>
                  dispatch({ t: "updateAttribute", entityId: e.id, index: i, patch: { isIdentity: ev.target.checked } })
                }
              />
              identity
            </label>
            <label className="erd-flag">
              <input
                type="checkbox"
                checked={!!a.nullable}
                disabled={!!a.isPrimaryKey}
                onChange={(ev) =>
                  dispatch({ t: "updateAttribute", entityId: e.id, index: i, patch: { nullable: ev.target.checked } })
                }
              />
              null
            </label>
            <button
              className="btn ghost small"
              onClick={() => dispatch({ t: "deleteAttribute", entityId: e.id, index: i })}
              aria-label="Remove column"
            >
              ×
            </button>
          </div>
        ))}

        <div className="erd-inspector-actions">
          <button className="btn small" onClick={() => dispatch({ t: "addAttribute", entityId: e.id })}>
            + Column
          </button>
          <button className="btn ghost small" onClick={() => dispatch({ t: "deleteEntity", id: e.id })}>
            Delete table
          </button>
        </div>
      </div>
    );
  }

  const r = model.relationships.find((x) => x.id === selection.id);
  if (!r) return <div className="erd-inspector" />;
  const nameOf = (id: string) => model.entities.find((e) => e.id === id)?.name ?? "?";

  return (
    <div className="erd-inspector">
      <div className="props-sub">Relationship</div>
      <p className="erd-rel-summary">
        <strong>{nameOf(r.fromEntityId)}</strong>.{r.fromColumns.join(", ")} →{" "}
        <strong>{nameOf(r.toEntityId)}</strong>.{r.toColumns.join(", ")}
      </p>
      <p className="muted erd-rel-note">
        The foreign key lives on {nameOf(r.fromEntityId)} — the “many” side.
      </p>

      <label className="erd-field">
        <span>Cardinality</span>
        <select
          className="erd-input"
          value={r.cardinality}
          onChange={(ev) =>
            dispatch({ t: "updateRelationship", id: r.id, patch: { cardinality: ev.target.value as Cardinality } })
          }
        >
          <option value="manyToOne">many-to-one</option>
          <option value="oneToOne">one-to-one</option>
          <option value="manyToMany">many-to-many</option>
        </select>
      </label>

      <label className="erd-field">
        <span>On delete</span>
        <select
          className="erd-input"
          value={r.onDelete}
          onChange={(ev) =>
            dispatch({ t: "updateRelationship", id: r.id, patch: { onDelete: ev.target.value as ReferentialAction } })
          }
        >
          <option value="NO ACTION">NO ACTION — refuse while children exist</option>
          <option value="CASCADE">CASCADE — delete the children too</option>
          <option value="SET NULL">SET NULL — orphan the children</option>
        </select>
      </label>

      <div className="erd-inspector-actions">
        <button className="btn ghost small" onClick={() => dispatch({ t: "deleteRelationship", id: r.id })}>
          Delete relationship
        </button>
      </div>
    </div>
  );
}
