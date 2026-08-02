import { useCallback, useMemo } from "react";
import {
  Background,
  BackgroundVariant,
  Controls,
  Handle,
  MiniMap,
  Position,
  ReactFlow,
  type Edge,
  type Node,
  type NodeProps,
  type OnConnect,
  type NodeChange,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import type { ErdModel } from "./types";
import type { ErdAction } from "./model";

type EntityData = {
  name: string;
  attributes: { name: string; dataType: string; nullable?: boolean; isPrimaryKey?: boolean }[];
  fkColumns: Set<string>;
};

// A table card: name header, then one row per column with its type and key
// badges. Each row carries its own connection handles so a relationship is drawn
// between the columns it actually links, not between two boxes.
function EntityNode({ data, selected }: NodeProps<Node<EntityData>>) {
  return (
    <div className={`erd-node ${selected ? "selected" : ""}`}>
      <div className="erd-node-head">{data.name}</div>
      <div className="erd-node-body">
        {data.attributes.length === 0 && <div className="erd-attr erd-attr-empty">no columns</div>}
        {data.attributes.map((a) => (
          <div className="erd-attr" key={a.name}>
            <Handle type="target" position={Position.Left} id={`${a.name}-t`} className="erd-port" />
            <span className="erd-attr-key">
              {a.isPrimaryKey ? "PK" : data.fkColumns.has(a.name.toLowerCase()) ? "FK" : ""}
            </span>
            <span className="erd-attr-name">{a.name}</span>
            <span className="erd-attr-type">
              {a.dataType}
              {a.nullable && !a.isPrimaryKey ? " ?" : ""}
            </span>
            <Handle type="source" position={Position.Right} id={`${a.name}-s`} className="erd-port" />
          </div>
        ))}
      </div>
    </div>
  );
}

const nodeTypes = { entity: EntityNode };

export function ErdCanvas({
  model,
  dispatch,
  onSelect,
  selectedId,
}: {
  model: ErdModel;
  dispatch: (a: ErdAction) => void;
  onSelect: (sel: { kind: "entity" | "relationship"; id: string } | null) => void;
  selectedId: string | null;
}) {
  const nodes: Node<EntityData>[] = useMemo(() => {
    const fkByEntity = new Map<string, Set<string>>();
    for (const r of model.relationships) {
      const set = fkByEntity.get(r.fromEntityId) ?? new Set<string>();
      r.fromColumns.forEach((c) => set.add(c.toLowerCase()));
      fkByEntity.set(r.fromEntityId, set);
    }
    return model.entities.map((e) => ({
      id: e.id,
      type: "entity",
      position: { x: e.x, y: e.y },
      selected: e.id === selectedId,
      data: { name: e.name, attributes: e.attributes, fkColumns: fkByEntity.get(e.id) ?? new Set() },
    }));
  }, [model, selectedId]);

  const edges: Edge[] = useMemo(
    () =>
      model.relationships.map((r) => ({
        id: r.id,
        source: r.fromEntityId,
        target: r.toEntityId,
        sourceHandle: r.fromColumns[0] ? `${r.fromColumns[0]}-s` : undefined,
        targetHandle: r.toColumns[0] ? `${r.toColumns[0]}-t` : undefined,
        // smoothstep is React Flow's orthogonal router — the elbow shape the
        // reference design uses.
        type: "smoothstep",
        selected: r.id === selectedId,
        label: r.cardinality === "oneToOne" ? "1 — 1" : r.cardinality === "manyToMany" ? "∞ — ∞" : "∞ — 1",
        className: `erd-edge ${r.id === selectedId ? "selected" : ""}`,
      })),
    [model, selectedId],
  );

  const onNodesChange = useCallback(
    (changes: NodeChange<Node<EntityData>>[]) => {
      for (const c of changes) {
        if (c.type === "position" && c.position) {
          dispatch({ t: "moveEntity", id: c.id, x: c.position.x, y: c.position.y });
        }
      }
    },
    [dispatch],
  );

  const onConnect: OnConnect = useCallback(
    (c) => {
      if (!c.source || !c.target) return;
      // Dragging from a child's column to the parent it points at.
      dispatch({
        t: "connect",
        fromEntityId: c.source,
        toEntityId: c.target,
        column: c.sourceHandle?.replace(/-s$/, ""),
      });
    },
    [dispatch],
  );

  return (
    <div className="erd-canvas">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        nodeTypes={nodeTypes}
        onNodesChange={onNodesChange}
        onConnect={onConnect}
        onNodeClick={(_, n) => onSelect({ kind: "entity", id: n.id })}
        onEdgeClick={(_, e) => onSelect({ kind: "relationship", id: e.id })}
        onPaneClick={() => onSelect(null)}
        onNodeContextMenu={(ev, n) => {
          ev.preventDefault();
          onSelect({ kind: "entity", id: n.id });
        }}
        onEdgeContextMenu={(ev, e) => {
          ev.preventDefault();
          onSelect({ kind: "relationship", id: e.id });
        }}
        fitView
        // Without a maxZoom, fitView on a one-table starting model scales that
        // single node up to fill the whole canvas.
        fitViewOptions={{ maxZoom: 1, padding: 0.25 }}
        minZoom={0.2}
        maxZoom={1.75}
        proOptions={{ hideAttribution: true }}
      >
        <Background variant={BackgroundVariant.Dots} gap={18} size={1} />
        <MiniMap pannable zoomable className="erd-minimap" />
        <Controls showInteractive={false} />
      </ReactFlow>
    </div>
  );
}
