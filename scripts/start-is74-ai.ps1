#Requires -Version 5.1
<#
.SYNOPSIS
    Второй инстанс CV-нейронки (YOLO) — городская камера is74 «Свердловский — Ленина».

.DESCRIPTION
    cv_service.py самодостаточно настраивается через переменные окружения, поэтому
    той же программой обслуживаем и OBS (порт 6545, запускается вручную), и is74:

        CV_SOURCE  https://cdn.cams.is74.ru/... (HLS, OpenCV/FFMPEG умеют сразу)
        6546       /stream.mjpg  (кадры с рамками YOLO)  + /alerts/longpoll
                   /health       (источник/модель/очередь алертов)

    Мост deploy-bridge-1 (в SOsi) опрашивает оба сервиса (CV_SERVICE_URLS) и
    доставляет алерты в backend → инциденты в панели оператора.

    Отдельный каталог снапшотов (alert_images_is74) — чтобы фото инцидентов
    is74 не смешивались с_OBS.

.PARAMETER Stop
    Остановить инстанс (по PID-файлу).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\start-is74-ai.ps1
    powershell -ExecutionPolicy Bypass -File scripts\start-is74-ai.ps1 -Stop
#>
[CmdletBinding()]
param(
    [switch]$Stop
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Path $PSScriptRoot -Parent   # ...\SOsi-AIO
$cv = Join-Path $root 'cv_branch'
$py = Join-Path $cv '.venv\Scripts\python.exe'
$pidFile = Join-Path $cv 'is74-ai.pid'
$logs = Join-Path $cv 'logs'

if (-not (Test-Path -LiteralPath $py)) {
    throw "Не найден venv python: $py (создайте venv по cv_branch/README.md)"
}

function Get-RunningAiPid {
    if (-not (Test-Path -LiteralPath $pidFile)) { return $null }
    $stored = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue
    if (-not $stored) { return $null }
    $proc = Get-Process -Id $stored -ErrorAction SilentlyContinue
    if ($proc) { return $stored }
    Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
    return $null
}

if ($Stop) {
    $running = Get-RunningAiPid
    if ($running) {
        Stop-Process -Id $running -Force
        Write-Host "Остановлен инстанс is74-AI (PID $running)."
    } else {
        Write-Host "Инстанс is74-AI не запущен."
    }
    exit 0
}

if (Get-RunningAiPid) {
    Write-Host "Инстанс is74-AI уже запущен (PID $((Get-Content -LiteralPath $pidFile)))."
    exit 0
}

New-Item -ItemType Directory -Force -Path $logs | Out-Null

# --- поток и модель ---
# HLS is74 (camId=23889, «Свердловский — Ленина»). OpenCV/FFMPEG открывает https сам.
$env:CAMERA_SOURCE = 'https://cdn.cams.is74.ru/hls/playlists/ts.m3u8?uuid=53d8b16a-b583-4a7e-954d-4837855fe8a0&quality=main'
$env:CV_SERVICE_PORT = '6546'
# Снапшоты инцидентов is74 отдельно от OBS
$env:ALERT_IMAGE_DIR = 'alert_images_is74'
# Исходник 2688x1520: публикуемый MJPEG ужимаем до ~1210px по ширине
# (инференс всё равно letterbox'ит к CV_IMGSZ=480, это только выдача в панель)
$env:CV_PUBLISH_SCALE = '0.45'

$started = Start-Process -FilePath $py -ArgumentList 'cv_service.py' `
    -WorkingDirectory $cv `
    -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $logs 'is74-ai.out.log') `
    -RedirectStandardError (Join-Path $logs 'is74-ai.err.log') `
    -PassThru

Set-Content -LiteralPath $pidFile -Value $started.Id
Write-Host "Инстанс is74-AI запущен: PID $($started.Id)"
Write-Host "  MJPEG    : http://<host>:6546/stream.mjpg  (рамки YOLO)"
Write-Host "  Health   : http://<host>:6546/health"
Write-Host "  Alerts   : http://<host>:6546/alerts/longpoll  (опрашивает deploy-bridge-1)"
Write-Host "  Логи     : $logs\is74-ai.*.log"
