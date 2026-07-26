<#
.SYNOPSIS
  Disaster recovery: delete the SQL Server container/image and recreate them from scratch.

.DESCRIPTION
  Use this if the sqlperf-sqlserver container or its image was deleted (or you want a
  guaranteed-clean SQL Server). It:
    1. Stops and removes the sqlperf-sqlserver container
    2. Removes the mssql-data volume (all data is lost -- lesson databases and AppMeta)
    3. Pulls a fresh mssql/server:2022-latest image
    4. Recreates the container via docker compose and waits for it to become healthy

  After this finishes, open the app's Settings page and click "Reset All Lesson
  Databases" to recreate every lesson's database from its seed.sql -- no manual SQL
  scripts required.

.PARAMETER KeepData
  Skip removing the mssql-data volume (keeps existing databases if the container/image
  were deleted but the volume survived).
#>
param(
    [switch]$KeepData
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "== Stopping and removing sqlperf-sqlserver container ==" -ForegroundColor Cyan
docker rm -f sqlperf-sqlserver 2>$null | Out-Null

Write-Host "== Removing the mssql/server:2022-latest image ==" -ForegroundColor Cyan
docker rmi mcr.microsoft.com/mssql/server:2022-latest 2>$null | Out-Null

if (-not $KeepData) {
    Write-Host "== Removing the mssql-data volume (ALL DATA WILL BE LOST) ==" -ForegroundColor Yellow
    docker volume rm sql-performance_mssql-data 2>$null | Out-Null
} else {
    Write-Host "== Keeping mssql-data volume (-KeepData) ==" -ForegroundColor Cyan
}

Write-Host "== Pulling a fresh SQL Server 2022 image ==" -ForegroundColor Cyan
docker pull mcr.microsoft.com/mssql/server:2022-latest

Write-Host "== Recreating the sqlserver container via docker compose ==" -ForegroundColor Cyan
docker compose up -d sqlserver

Write-Host "== Waiting for SQL Server to report healthy ==" -ForegroundColor Cyan
$deadline = (Get-Date).AddMinutes(3)
do {
    Start-Sleep -Seconds 5
    $status = docker inspect --format '{{.State.Health.Status}}' sqlperf-sqlserver 2>$null
    Write-Host "  status: $status"
} while ($status -ne "healthy" -and (Get-Date) -lt $deadline)

if ($status -ne "healthy") {
    Write-Warning "SQL Server did not report healthy within 3 minutes -- check 'docker logs sqlperf-sqlserver'."
    exit 1
}

Write-Host ""
Write-Host "SQL Server container recreated and healthy." -ForegroundColor Green
Write-Host "Next: restart the API (docker compose restart api) if it's running, then open" -ForegroundColor Green
Write-Host "the app's Settings page and click 'Reset All Lesson Databases'." -ForegroundColor Green
