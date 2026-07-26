# SQL Performance Playground a.k.a. "Seek and Destroy"

**Repo:** https://github.com/johanccs/seek-and-destroy-sql

An interactive, web-based playground for developing **Microsoft SQL Server performance-tuning**
skills — from beginner to expert. You write real T-SQL against a **real SQL Server 2022 engine**,
see genuine execution plans, `STATISTICS IO/TIME`, locking and deadlocks, and each lesson grades
your fix automatically.

This is a learning tool for query performance (indexes, bad query patterns, plan reading,
blocking/deadlocks, tempdb pressure, statistics/caching) — **not** a SQL-syntax tutorial.

## Architecture

Three containers, orchestrated by `docker-compose.yml`:

| Service     | What it is                        | Host port |
|-------------|-----------------------------------|-----------|
| `sqlserver` | SQL Server 2022 (lesson DBs + `AppMeta` progress DB) | 14330 → 1433 |
| `api`       | ASP.NET Core (C#) — runs your SQL, captures plan+stats, grades pass conditions, drives scripted deadlock demos | 5080 → 8080 |
| `web`       | React SPA (Monaco editor, graphical plan viewer, stats dashboard, deadlock timeline) | 5173 → 80 |

See [`docs/CONTRACT.md`](docs/CONTRACT.md) for the full API + lesson-manifest specification.

## Quick start

```bash
cp .env.example .env          # optional: change the SA password
docker compose up --build
```

Then open **http://localhost:5173**.

The API seeds each lesson's database on first access and creates the `AppMeta` progress
database automatically. Progress persists across restarts (stored in `AppMeta`).

## How a lesson works

1. Pick a lesson from the sidebar (grouped Beginner → Expert).
2. Read the scenario, run the deliberately-slow **starting query**, and inspect the
   **Execution Plan** and **Statistics** tabs.
3. Improve it — add an index, rewrite the query, update statistics, reorder a transaction…
4. Re-run. The **pass/fail banner** shows exactly which measurable conditions you've met
   (e.g. *no Table Scan*, *logical reads < 200*, *Index Seek used*).
5. **Reset Lesson** restores the original slow state at any time.

**Concurrency lessons** (blocking/deadlocks) show two editable session scripts; the API runs
them as two real interleaved connections server-side and streams back a timeline showing who
blocked whom and which session was chosen as the deadlock victim.

## Curriculum

~20 lessons per level across four levels (~80 total), covering: indexing (missing/unused/
covering/filtered), sargability & query rewriting, join algorithms, execution-plan reading,
blocking & deadlocks, tempdb spills & contention, statistics staleness & cardinality
estimation, parameter sniffing & plan cache, isolation levels & lock escalation, parallelism,
columnstore, and holistic real-world case studies.

Lessons live under `lessons/<level>/<id>/` as `manifest.json` + `seed.sql` + `solution.sql`.
Adding a lesson is pure content — no code changes — following the schema in `docs/CONTRACT.md`.

## Repo layout

```
docker-compose.yml     three-service orchestration
docs/CONTRACT.md       authoritative API + manifest spec
lessons/               lesson content (data + manifests)
api/SqlPerf.Api/       ASP.NET Core Web API
web/                   React + Vite SPA
```

## Local development (without Docker)

- **API:** `cd api/SqlPerf.Api && dotnet run` (set `ConnectionStrings__Sql` to your SQL Server,
  e.g. `Server=localhost,14330;User Id=sa;Password=...;TrustServerCertificate=True;`).
- **Web:** `cd web && npm install && npm run dev` (reads `VITE_API_BASE`, default
  `http://localhost:5080`).

> Note: the SPA loads the Monaco editor engine from a CDN at runtime, so first load needs
> internet access.

## Settings & disaster recovery

The app has a **Settings** page (⚙ in the sidebar) for environment status and database
administration — no manual SQL scripts required day-to-day:

- **Reset All Lesson Databases** — re-runs every lesson's `seed.sql`, recreating all 80
  lesson databases from scratch. Use after a fresh install or after the SQL container's
  data volume was recreated.
- **Reset My Progress** — clears recorded lesson-completion progress (`AppMeta` DB).
- **Recreate SQL Server Container** — full disaster recovery, run with one click: deletes
  the `sqlperf-sqlserver` container and image, pulls a fresh SQL Server 2022 image,
  recreates the container via `docker compose`, waits for it to become healthy, then
  reseeds every lesson database automatically.

**How the one-click container recreate works:** the `api` container has the **host's Docker
socket** (`/var/run/docker.sock`) and the project directory bind-mounted in (see
`docker-compose.yml`), plus the Docker CLI and Compose plugin installed (see
`api/Dockerfile`). This lets it run `docker`/`docker compose` commands against the host's
Docker daemon directly (the "Docker-outside-of-Docker" pattern) — no separate orchestration
tool needed.

> ⚠️ **Security note:** mounting the Docker socket gives the `api` container full control
> of the **host's** Docker daemon (equivalent to root on the host). This is appropriate for
> a trusted local/dev machine only. **Never enable this mount in a shared or
> internet-facing deployment** (including the Azure deployment below) — remove the
> `docker.sock`/`.:/workspace` volume mounts from the `api` service, and rely on the
> standalone scripts (`scripts/recreate-sql-container.ps1` / `.sh`) or your platform's own
> redeploy mechanism instead. The Settings page's fallback instructions cover this.

If the API can't reach Docker (socket not mounted, remote host, etc.), run the equivalent
script yourself from the project root:

```bash
# Windows (PowerShell)
./scripts/recreate-sql-container.ps1

# macOS / Linux
./scripts/recreate-sql-container.sh
```

## Deploying to Azure

This app is three containers plus one stateful engine (SQL Server), so the deployment
decision that matters most is **how you host SQL Server** — it determines how faithfully
the curriculum's 80 lessons (compatibility-level tricks, columnstore, partitioning, page
compression, snapshot/RCSI isolation, lock escalation, `system_health` deadlock graphs)
behave identically to local Docker.

| Option | Compatibility with the lessons | Cost / ops effort |
|---|---|---|
| **A. Containerized SQL Server 2022** (same image as local, on Azure Container Apps or Container Instances, backed by an Azure Files share for `/var/opt/mssql`) | **Identical to local** — same engine, same image | Low-medium cost; you manage the container like any other |
| **B. SQL Server on an Azure VM** | **Identical to local** | Higher cost; you patch/manage the OS |
| **C. Azure SQL Database (PaaS)** | Mostly compatible, but **not guaranteed identical** for every lesson — some DBCC/legacy-CE/partitioning/XEvent behaviors differ subtly on the PaaS engine | Cheapest, fully managed, scales down easily |
| **D. Azure SQL Managed Instance** | Closest PaaS analog to full SQL Server; safest managed option | Most expensive PaaS tier; slow to provision |

**Recommended default: Option A** (containerized SQL Server 2022 on Azure Container Apps) —
it reuses the exact image and seed scripts already in this repo with zero lesson changes,
while still being a "cloud-native" container deployment.

### High-level steps (Option A)

1. **Registry:** push the `api` and `web` images to Azure Container Registry (ACR).
   ```bash
   az acr create -n <acrName> -g <rg> --sku Basic
   az acr build -r <acrName> -t sqlperf-api:latest ./api
   az acr build -r <acrName> -t sqlperf-web:latest ./web
   ```
2. **Persistent storage for SQL Server:** create an Azure Files share and mount it as the
   `sqlserver` container's `/var/opt/mssql` volume (Container Apps and Container Instances
   both support Azure Files mounts).
3. **Container Apps Environment:** create one environment and three container apps
   (`sqlserver`, `api`, `web`) inside it so they share a virtual network and can reach each
   other by name — mirroring the `docker-compose.yml` topology. Give `sqlserver` and `api`
   **internal-only** ingress; expose `web` (and optionally `api`, if the SPA needs direct
   browser calls) externally with HTTPS.
   ```bash
   az containerapp env create -n sqlperf-env -g <rg> --location <region>
   az containerapp create -n sqlperf-sqlserver -g <rg> --environment sqlperf-env \
     --image mcr.microsoft.com/mssql/server:2022-latest \
     --env-vars ACCEPT_EULA=Y MSSQL_SA_PASSWORD=secretref:sa-password MSSQL_PID=Developer \
     --ingress internal --target-port 1433
   az containerapp create -n sqlperf-api -g <rg> --environment sqlperf-env \
     --image <acrName>.azurecr.io/sqlperf-api:latest \
     --env-vars ConnectionStrings__Sql="Server=sqlperf-sqlserver;User Id=sa;Password=secretref:sa-password;TrustServerCertificate=True;" \
     --ingress internal --target-port 8080
   az containerapp create -n sqlperf-web -g <rg> --environment sqlperf-env \
     --image <acrName>.azurecr.io/sqlperf-web:latest \
     --ingress external --target-port 80
   ```
   (Bake the real API URL into the `web` image's `VITE_API_BASE` build arg, or front both
   with Azure Front Door / an Application Gateway for a single hostname.)
4. **Remove the Docker-socket mount** from the `api` service definition for this
   environment — Container Apps has no host Docker daemon to reach, and you should not run
   with that privilege in a shared cloud environment anyway. Use `scripts/recreate-sql-container.*`
   locally, or redeploy the `sqlserver` container app (`az containerapp update` /
   `az containerapp revision restart`), for disaster recovery instead.
5. **Secrets:** store `MSSQL_SA_PASSWORD` in Container Apps secrets (`--secrets sa-password=...`)
   or Azure Key Vault, not in plain env vars.
6. **Seed on first boot:** the API already seeds each lesson's database on first access
   (`EnsureSeededAsync`), so no extra migration step is needed — just hit the app once it's
   deployed, or click **Reset All Lesson Databases** in Settings.

> This repo doesn't yet include ready-to-run Bicep/Terraform for Azure — the steps above
> are the architecture and CLI commands to follow. Ask for IaC templates once you've picked
> an option above (A/B/C/D) and I can generate and wire them up.
