// The Database Design curriculum, in teaching order.
//
// Only modules with an `id` are built; the rest are the published plan. Keeping
// the whole outline visible is deliberate — a learner should be able to see
// where a module sits in the arc before deciding to start it — but nothing here
// is allowed to pretend to be finished. `id` is the single source of that truth,
// and the backend, not this file, decides what actually exists.

export type RoadmapEntry = { n: number; title: string; blurb: string; id?: string };
export type RoadmapLevel = { level: string; title: string; widget: string; entries: RoadmapEntry[] };

export const ROADMAP: RoadmapLevel[] = [
  {
    level: "beginner",
    title: "Beginner",
    widget: "ERD canvas, guided",
    entries: [
      { n: 1, title: "What a data model is", blurb: "Entities, attributes and relationships — the three things every model is made of." },
      { n: 2, title: "Tables, rows, columns and schemas", blurb: "What the engine actually stores, and what a schema is for." },
      { n: 3, title: "Choosing data types", blurb: "What nvarchar(max) everywhere really costs you." },
      { n: 4, title: "Primary keys: natural vs surrogate", blurb: "When the real-world identifier is the right key, and when it isn't." },
      { n: 5, title: "One-to-many relationships", blurb: "The shape most of a database is made of, and which side carries the key.", id: "d-b-05-one-to-many" },
      { n: 6, title: "One-to-one, and when it's really inheritance", blurb: "A rarer shape that usually means something else is going on.", id: "d-b-06-one-to-one" },
      { n: 7, title: "Many-to-many and the junction table", blurb: "Why the engine has no direct way to store this, and what to do instead.", id: "d-b-07-many-to-many" },
      { n: 8, title: "NULLs, defaults and optionality", blurb: "Saying 'we don't know' without saying 'zero'." },
      { n: 9, title: "Constraints as executable documentation", blurb: "CHECK and UNIQUE: rules the database enforces rather than the team remembering." },
      { n: 10, title: "Capstone: an order-entry system", blurb: "Model the whole thing end to end, from a written brief." },
    ],
  },
  {
    level: "intermediate",
    title: "Intermediate",
    widget: "Normalization stepper + canvas",
    entries: [
      { n: 11, title: "Why normalize — the anomalies", blurb: "Update, insert and delete anomalies shown live, before any rule is named." },
      { n: 12, title: "1NF: repeating groups", blurb: "Phone1, Phone2, Phone3 — and the comma-separated column that is just as bad." },
      { n: 13, title: "2NF: partial dependencies", blurb: "Attributes that depend on only part of a composite key." },
      { n: 14, title: "3NF: transitive dependencies", blurb: "Facts about a fact, and the lookup table they belong in." },
      { n: 15, title: "BCNF: when 3NF isn't enough", blurb: "The overlapping-candidate-key case that 3NF lets through." },
      { n: 16, title: "4NF and 5NF", blurb: "Multivalued and join dependencies — rarer, but real." },
      { n: 17, title: "Denormalizing on purpose", blurb: "When to break the rules, and how to keep that decision honest." },
      { n: 18, title: "Naming conventions and schema organisation", blurb: "Consistency as a performance feature for humans." },
      { n: 19, title: "Capstone: spreadsheet to BCNF", blurb: "Decompose a deliberately awful flat table, step by step." },
    ],
  },
  {
    level: "advanced",
    title: "Advanced",
    widget: "Canvas + SQL runner + plan tree",
    entries: [
      { n: 20, title: "How indexes are stored", blurb: "B-trees, and what clustered actually means." },
      { n: 21, title: "Choosing the clustered index key", blurb: "The decision every other index inherits." },
      { n: 22, title: "Covering and composite indexes", blurb: "Designing an index for a stated workload rather than a column." },
      { n: 23, title: "Indexing foreign keys", blurb: "The delete-plan and deadlock cost of the index SQL Server won't create for you." },
      { n: 24, title: "Over-indexing and write amplification", blurb: "Measured with real DML, not asserted." },
      { n: 25, title: "Reading an execution plan", blurb: "What the optimizer decided, and what that says about your design." },
      { n: 26, title: "Constraints the optimizer uses", blurb: "Trusted foreign keys and CHECK constraints that make plans faster." },
      { n: 27, title: "Views and indexed views", blurb: "Abstraction that helps, and abstraction that costs." },
      { n: 28, title: "Capstone: index for a workload", blurb: "Graded on logical reads against a given query set." },
    ],
  },
  {
    level: "expert",
    title: "Expert",
    widget: "SQL runner + schema inspector",
    entries: [
      { n: 29, title: "Stored procedures as an interface", blurb: "The API boundary, and what it does for plan reuse." },
      { n: 30, title: "Scalar UDFs vs inline TVFs", blurb: "Both measured, so the difference is a number rather than an opinion." },
      { n: 31, title: "Triggers and the four ways they bite", blurb: "When a trigger is right, and when a constraint was the answer." },
      { n: 32, title: "Temporal and slowly-changing history", blurb: "Modelling 'what did this look like in March?'" },
      { n: 33, title: "OLTP vs OLAP: the same data, twice", blurb: "Normalized and star schema side by side, with the trade-off made explicit." },
      { n: 34, title: "Anti-pattern gallery", blurb: "EAV, polymorphic keys, god tables and IsDeleted sprawl — with the numbers that condemn them." },
      { n: 35, title: "Capstone: design and defend", blurb: "A written brief, your schema, and a review of the decisions you made." },
    ],
  },
];
