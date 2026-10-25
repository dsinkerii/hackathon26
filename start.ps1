#Requires -Version 5.1
<#
.SYNOPSIS
    Build and start the Safe Playground stack with Docker.

.PARAMETER Demo
    Also start the synthetic camera and seed a camera entry, so video works
    without a webcam.

.PARAMETER NoBrowser
    Do not open the operator app after the stack is up.

.EXAMPLE
    .\start.ps1
    .\start.ps1 -Demo
#>
[CmdletBinding()]
param(
    [switch]$Demo,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

function Fail($message) {
    Write-Host ""
    Write-Host $message -ForegroundColor Red
    exit 1
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail @"
Docker was not found.

Install Docker Desktop for Windows, then run this script again:
  https://docs.docker.com/desktop/setup/install/windows-install/

You do not need Flutter, Java, Maven, Python or Node on the host.
"@
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "Docker Desktop is installed but not running. Start it, wait for the whale icon, then retry."
}

if (-not (Test-Path -LiteralPath '.env')) {
    Copy-Item -LiteralPath '.env.example' -Destination '.env'
    Write-Host "Created .env from .env.example (change the secrets before sharing)."
}

$webPort = '5173'
$backendPort = '8086'
$cameraPort = '8090'
$demoUrl = 'http://localhost:8090/stream.mjpg'
$adminUser = 'playground'
$adminPassword = 'playground-demo'
if (Test-Path -LiteralPath '.env') {
    foreach ($line in Get-Content -LiteralPath '.env') {
        if ($line -match '^\s*WEB_PORT\s*=\s*(.+?)\s*$') { $webPort = $Matches[1] }
        if ($line -match '^\s*BACKEND_PORT\s*=\s*(.+?)\s*$') { $backendPort = $Matches[1] }
        if ($line -match '^\s*CAMERA_PORT\s*=\s*(.+?)\s*$') { $cameraPort = $Matches[1] }
        if ($line -match '^\s*DEMO_CAMERA_URL\s*=\s*(.+?)\s*$') { $demoUrl = $Matches[1] }
        if ($line -match '^\s*INITIAL_ADMIN_USERNAME\s*=\s*(.+?)\s*$') { $adminUser = $Matches[1] }
        if ($line -match '^\s*INITIAL_ADMIN_PASSWORD\s*=\s*(.+?)\s*$') { $adminPassword = $Matches[1] }
    }
}

$composeArgs = @('compose')
if ($Demo) { $composeArgs += @('--profile', 'demo') }
$composeArgs += @('up', '--build', '-d')

Write-Host ""
Write-Host "Building and starting containers (the first run downloads images)..." -ForegroundColor Cyan
& docker @composeArgs
if ($LASTEXITCODE -ne 0) { Fail "docker compose failed with exit code $LASTEXITCODE" }

$url = "http://localhost:$webPort"
Write-Host ""
Write-Host "Waiting for the operator app at $url ..." -ForegroundColor Cyan

$ready = $false
for ($attempt = 0; $attempt -lt 90; $attempt++) {
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}

if (-not $ready) {
    Write-Host "The stack is still starting. Check it with:" -ForegroundColor Yellow
    Write-Host "  docker compose logs -f"
    exit 1
}

Write-Host ""
Write-Host "Operator app : $url" -ForegroundColor Green
Write-Host "Backend API  : http://localhost:$backendPort" -ForegroundColor Green
if ($Demo) {
    Write-Host "Demo stream  : http://localhost:$cameraPort/stream.mjpg" -ForegroundColor Green
}
Write-Host "Login        : $adminUser / $adminPassword"
Write-Host ""
Write-Host "Add your own camera in the app with stream URL:"
Write-Host "  $demoUrl" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Stop with: docker compose down"
if ($Demo) { Write-Host "Reset all data with: docker compose --profile demo down -v" }

if (-not $NoBrowser) {
    Start-Process $url
}
