import type { ErdModel, Cardinality, ReferentialAction } from "./types";
import { CHECK_OPERATORS, DATA_TYPES, DEFAULT_FUNCTIONS } from "./types";
import type { ErdAction } from "./model";

export type Selection = { kind: "entity" | "relationship"; id: string } | null;

// Properties for whatever is selected — reachable by clicking or right-clicking
// an object on the canvas. Nothing here is cosmetic: every field maps to
// something the generated DDL emits.
export function Inspector({
  model,
  selection,
  dispatch,
  collapsed = false,
}: {
  model: ErdModel;
  selection: Selection;
  dispatch: (a: ErdAction) => void;
  collapsed?: boolean;
}) {
  if (!selection) {
    return (
      <div className={`erd-inspector ${collapsed ? "pane-collapsed" : ""}`}>
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
      <div className={`erd-inspector ${collapsed ? "pane-collapsed" : ""}`}>
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
            <label className="erd-flag" title="Unique, but not the identifier — emitted as a UNIQUE constraint">
              <input
                type="checkbox"
                checked={!!a.isUnique}
                disabled={!!a.isPrimaryKey}
                onChange={(ev) =>
                  dispatch({ t: "updateAttribute", entityId: e.id, index: i, patch: { isUnique: ev.target.checked } })
                }
              />
              uq
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
            <input
              className="erd-input erd-default"
              value={a.defaultValue ?? ""}
              placeholder="default"
              title="DEFAULT — a number, text in single quotes, or SYSUTCDATETIME()"
              list="erd-default-suggestions"
              onChange={(ev) =>
                dispatch({ t: "updateAttribute", entityId: e.id, index: i, patch: { defaultValue: ev.target.value } })
              }
            />
            <button
              className="btn ghost small"
              onClick={() => dispatch({ t: "deleteAttribute", entityId: e.id, index: i })}
              aria-label="Remove column"
            >
              ×
            </button>
          </div>
        ))}

        <datalist id="erd-default-suggestions">
          {DEFAULT_FUNCTIONS.map((f) => (
            <option key={f} value={f} />
          ))}
        </datalist>

        <div className="props-sub">Checks</div>
        {(e.checks ?? []).length === 0 && (
          <p className="muted erd-rel-note">
            No CHECK constraints. A check is a rule the database enforces on every write.
          </p>
        )}
        {(e.checks ?? []).map((c, i) => (
          <div className="erd-check-edit" key={i}>
            <select
              className="erd-input"
              value={c.column}
              onChange={(ev) => dispatch({ t: "updateCheck", entityId: e.id, index: i, patch: { column: ev.target.value } })}
              aria-label="Check column"
            >
              {e.attributes.map((a) => (
                <option key={a.name} value={a.name}>{a.name}</option>
              ))}
            </select>
            <select
              className="erd-input"
              value={c.operator}
              onChange={(ev) =>
                dispatch({ t: "updateCheck", entityId: e.id, index: i, patch: { operator: ev.target.value as typeof c.operator } })
              }
              aria-label="Comparison"
            >
              {CHECK_OPERATORS.map((op) => (
                <option key={op} value={op}>{op}</option>
              ))}
            </select>
            <input
              className="erd-input"
              value={c.value}
              placeholder={c.operator === "IN" ? "'a', 'b'" : c.operator === "BETWEEN" ? "0, 100" : "0"}
              title="A number, or text in single quotes. IN takes a comma-separated list; BETWEEN takes two values."
              onChange={(ev) => dispatch({ t: "updateCheck", entityId: e.id, index: i, patch: { value: ev.target.value } })}
              aria-label="Value"
            />
            <button
              className="btn ghost small"
              onClick={() => dispatch({ t: "deleteCheck", entityId: e.id, index: i })}
              aria-label="Remove check"
            >
              ×
            </button>
          </div>
        ))}

        <div className="erd-inspector-actions">
          <button className="btn small" onClick={() => dispatch({ t: "addAttribute", entityId: e.id })}>
            + Column
          </button>
          <button className="btn small" onClick={() => dispatch({ t: "addCheck", entityId: e.id })}>
            + Check
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
    <div className={`erd-inspector ${collapsed ? "pane-collapsed" : ""}`}>
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
