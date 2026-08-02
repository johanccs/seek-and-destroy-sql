
**Context & Goal:**
I want to expand the existing SQL performance app by adding an interactive, module-based learning hub that teaches database design and modeling from beginner to expert level.

**Step-by-Step Instructions:**

1. **Context Gathering:**
   - Read `instructions.md`, `memory`, `azure`, and inspect the existing codebase to understand our current architectural patterns, state management, and styling conventions.
   - Inspect `image-1.png` for UI/UX inspiration, layout structure, and interactive components. - the image basically depicts an interactive design form where the user can drag and drop shapes in the canvas and connect them with edges - all objects have properties by right clicking on them to set. Look at https://dometrain.com/take/course/hands-on-system-design-for-beginners-3256117/adding-a-search-index-69958298/

2. **Scope & Core Capabilities:**
   - **Topics to Cover:** Database design fundamentals, tables/schemas, relationships, normalization (1NF to 5NF/BCNF), indexing strategies, query execution plans, triggers, functions, and stored procedures.
   - **Interactivity:** Provide interactive building blocks (e.g., visual ERD builders, normalization breakdown steps, query plan execution tree visualizers).
   - **Content Focus:** Emphasize enterprise best practices, common anti-patterns, and real-world trade-offs (e.g., OLTP vs. OLAP indexing).

3. **Navigation & Integration:**
   - Add this section as a distinct new route/component within the existing app.
   - Extend the top navigation bar to include a clear entry point for this module.

4. **Execution Strategy (Phased Approach):**
   - **Step 4A (Research & Plan):** Before writing feature code, present a detailed structural plan covering:
     - Component breakdown & route structure.
     - Proposed interactive UI tools/widgets inspired by `image-1.png` and industry-standard platforms (e.g., ByteByteGo, SQLBolt, Use The Index, Luke!).
     - Content outline grouped by skill level (Beginner → Intermediate → Advanced → Expert).
   - **Step 4B (Implementation):** Once I approve the plan, begin implementing the base navigation, page layout, and the first interactive core module.