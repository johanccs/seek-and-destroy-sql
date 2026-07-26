#!/usr/bin/env bash
# Disaster recovery: delete the SQL Server container/image and recreate them from scratch.
#
# Use this if the sqlperf-sqlserver container or its image was deleted (or you want a
# guaranteed-clean SQL Server). It:
#   1. Stops and removes the sqlperf-sqlserver container
#   2. Removes the mssql-data volume (ALL DATA IS LOST -- pass --keep-data to skip this)
#   3. Pulls a fresh mssql/server:2022-latest image
#   4. Recreates the container via docker compose and waits for it to become healthy
#
# After this finishes, open the app's Settings page and click "Reset All Lesson
# Databases" to recreate every lesson's database from its seed.sql -- no manual SQL
# scripts required.
set -euo pipefail

KEEP_DATA=false
if [[ "${1:-}" == "--keep-data" ]]; then
    KEEP_DATA=true
fi

cd "$(dirname "$0")/.."

echo "== Stopping and removing sqlperf-sqlserver container =="
docker rm -f sqlperf-sqlserver >/dev/null 2>&1 || true

echo "== Removing the mssql/server:2022-latest image =="
docker rmi mcr.microsoft.com/mssql/server:2022-latest >/dev/null 2>&1 || true

if [[ "$KEEP_DATA" == "false" ]]; then
    echo "== Removing the mssql-data volume (ALL DATA WILL BE LOST) =="
    docker volume rm sql-performance_mssql-data >/dev/null 2>&1 || true
else
    echo "== Keeping mssql-data volume (--keep-data) =="
fi

echo "== Pulling a fresh SQL Server 2022 image =="
docker pull mcr.microsoft.com/mssql/server:2022-latest

echo "== Recreating the sqlserver container via docker compose =="
docker compose up -d sqlserver

echo "== Waiting for SQL Server to report healthy =="
deadline=$((SECONDS + 180))
status=""
while [[ "$status" != "healthy" && $SECONDS -lt $deadline ]]; do
    sleep 5
    status=$(docker inspect --format '{{.State.Health.Status}}' sqlperf-sqlserver 2>/dev/null || echo "")
    echo "  status: ${status:-starting}"
done

if [[ "$status" != "healthy" ]]; then
    echo "WARNING: SQL Server did not report healthy within 3 minutes -- check 'docker logs sqlperf-sqlserver'." >&2
    exit 1
fi

echo ""
echo "SQL Server container recreated and healthy."
echo "Next: restart the API (docker compose restart api) if it's running, then open"
echo "the app's Settings page and click 'Reset All Lesson Databases'."
