# Driver para levantar y probar tcgmarketcordoba (backend Go + Flutter web).
# Uso:  pwsh .claude/skills/run-tcgmarketcordoba/driver.ps1 <start|smoke|shot|status|stop> [opciones]
# Ver SKILL.md en este directorio.
param(
  [Parameter(Position = 0)]
  [ValidateSet('start', 'stop', 'smoke', 'shot', 'status')]
  [string]$Command = 'smoke',
  [switch]$Build,                       # start: fuerza rebuild de flutter web
  [switch]$BackendOnly,                 # start: solo backend (dev.ps1 sirve la web)
  [string]$Url = 'http://localhost:5003',   # shot: URL a capturar
  [int]$Width = 1600,                   # shot: ancho de ventana
  [int]$Height = 900,                   # shot: alto de ventana
  [string]$Out,                         # shot: ruta del PNG de salida
  [string]$Query = 'jinx'               # smoke: búsqueda de carta (mín. 2 chars)
)

$ErrorActionPreference = 'Stop'
# driver.ps1 vive en <repo>/.claude/skills/run-tcgmarketcordoba/
$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$StateDir = Join-Path $env:TEMP 'tcgmarket-run'
$ShotsDir = Join-Path $StateDir 'shots'
$PidsFile = Join-Path $StateDir 'pids.json'
$Chrome   = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$ApiUrl   = 'http://localhost:8080'
$WebUrl   = 'http://localhost:5003'
New-Item -ItemType Directory -Force $StateDir, $ShotsDir | Out-Null

function Test-PortListening([int]$Port) {
  $null -ne (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Save-Pids($pids) { $pids | ConvertTo-Json | Set-Content $PidsFile }
function Load-Pids {
  if (Test-Path $PidsFile) { Get-Content $PidsFile | ConvertFrom-Json } else { $null }
}

function Wait-Healthy {
  foreach ($i in 1..30) {
    try {
      Invoke-RestMethod "$ApiUrl/health" -TimeoutSec 2 | Out-Null
      return $true
    } catch { Start-Sleep -Seconds 1 }
  }
  return $false
}

function Invoke-Start {
  $pids = @{ backend = $null; web = $null }

  # El build web va ANTES de arrancar el backend: con WEB_DIR seteado, el Go
  # lee build/web/index.html al inicio para la inyección de meta tags OG.
  $indexHtml = Join-Path $RepoRoot 'build\web\index.html'
  if (-not $BackendOnly -and ($Build -or -not (Test-Path $indexHtml))) {
    Write-Host 'web: flutter build web --release (tarda ~1 min)...'
    Push-Location $RepoRoot
    try { flutter build web --release } finally { Pop-Location }
  }

  if (Test-PortListening 8080) {
    Write-Host 'backend: ya hay algo escuchando en :8080, lo reuso'
  } else {
    Write-Host 'backend: compilando (go build)...'
    $serverExe = Join-Path $StateDir 'server.exe'
    Push-Location (Join-Path $RepoRoot 'backend')
    try { go build -o $serverExe . } finally { Pop-Location }
    # WorkingDirectory backend/ para que encuentre backend/.env. Con WEB_DIR
    # el mismo server sirve el SPA (como en prod) y se puede probar OG local.
    if (-not $BackendOnly) { $env:WEB_DIR = Join-Path $RepoRoot 'build\web' }
    try {
      $p = Start-Process $serverExe -WorkingDirectory (Join-Path $RepoRoot 'backend') `
        -WindowStyle Hidden -PassThru
    } finally {
      if (-not $BackendOnly) { Remove-Item Env:WEB_DIR -ErrorAction SilentlyContinue }
    }
    $pids.backend = $p.Id
    Write-Host "backend: pid $($p.Id)"
  }
  if (-not (Wait-Healthy)) { throw 'backend no respondió /health en 30s (¿backend/.env con DATABASE_URL?)' }
  Write-Host "backend: OK ($ApiUrl/health)"

  if ($BackendOnly) {
    Save-Pids $pids
    return
  }

  if (Test-PortListening 5003) {
    Write-Host 'web: ya hay algo escuchando en :5003, lo reuso'
  } else {
    $p = Start-Process python -ArgumentList '-m', 'http.server', '5003', '--directory', (Join-Path $RepoRoot 'build\web') `
      -WindowStyle Hidden -PassThru
    $pids.web = $p.Id
    Write-Host "web: pid $($p.Id)"
  }
  Save-Pids $pids
  Write-Host "web: $WebUrl"
}

function Invoke-Stop {
  $pids = Load-Pids
  foreach ($name in 'backend', 'web') {
    $procId = $pids.$name
    if ($procId) {
      try { Stop-Process -Id $procId -Force -Confirm:$false; Write-Host "${name}: pid $procId detenido" }
      catch { Write-Host "${name}: pid $procId ya no existe" }
    }
  }
  # por si quedó un server.exe huérfano de una corrida anterior
  Get-Process -Name server -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq (Join-Path $StateDir 'server.exe') } |
    Stop-Process -Force -Confirm:$false
  if (Test-Path $PidsFile) { Remove-Item $PidsFile }
}

function Invoke-Shot([string]$ShotUrl, [int]$W, [int]$H, [string]$OutFile) {
  if (-not $OutFile) {
    $OutFile = Join-Path $ShotsDir ("shot-{0}x{1}-{2:yyyyMMdd-HHmmss}.png" -f $W, $H, (Get-Date))
  }
  # --user-data-dir aislado es OBLIGATORIO: si Chrome ya está abierto con el
  # perfil default, el modo headless termina silenciosamente sin generar nada.
  # Args como strings pre-armados: PowerShell parte `--flag=(expr)` y
  # `--window-size=$W,$H` (la coma arma un array) en argumentos separados.
  # Perfil descartable: si persiste entre corridas, su disk cache sirve el
  # main.dart.js viejo y los screenshots muestran un build anterior.
  $profileDir = Join-Path $StateDir 'chrome-profile'
  if (Test-Path $profileDir) {
    Remove-Item $profileDir -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
  }
  $chromeArgs = @(
    '--headless=new', '--disable-gpu',
    "--user-data-dir=$profileDir",
    "--window-size=$W,$H",
    "--screenshot=$OutFile",
    '--virtual-time-budget=15000',
    $ShotUrl
  )
  if (Test-Path $OutFile) { Remove-Item $OutFile -Confirm:$false }
  & $Chrome @chromeArgs 2>$null | Out-Null
  # chrome.exe se desprende del proceso launcher: el PNG aparece DESPUÉS de
  # que el comando retorna. Esperar a que exista (hasta 30s).
  foreach ($i in 1..60) {
    if (Test-Path $OutFile) { break }
    Start-Sleep -Milliseconds 500
  }
  if (-not (Test-Path $OutFile)) { throw "Chrome no generó el screenshot ($OutFile)" }
  Start-Sleep -Milliseconds 500   # margen para que termine de escribirse
  Write-Host "screenshot: $OutFile"
  return $OutFile
}

function Invoke-Smoke {
  Write-Host '--- smoke: API ---'
  Invoke-RestMethod "$ApiUrl/health" -TimeoutSec 5 | Out-Null
  Write-Host '1. /health OK'

  # Usuario de smoke fijo (una sola alta; corridas siguientes hacen signin)
  $creds = @{ email = 'smoke@tcgsmoke.local'; password = 'smoke123456' } | ConvertTo-Json
  try {
    $auth = Invoke-RestMethod "$ApiUrl/auth/signup" -Method Post -ContentType 'application/json' -Body $creds
    Write-Host '2. signup OK (usuario smoke creado)'
  } catch {
    $auth = Invoke-RestMethod "$ApiUrl/auth/signin" -Method Post -ContentType 'application/json' -Body $creds
    Write-Host '2. signin OK (usuario smoke ya existía)'
  }
  $headers = @{ Authorization = "Bearer $($auth.access_token)" }

  # el endpoint devuelve [] con menos de 2 caracteres
  $printings = Invoke-RestMethod "$ApiUrl/cards/search?q=$Query" -Headers $headers
  if (-not $printings) { throw "sin resultados para '$Query' — probar otra -Query o cargar datos de referencia" }
  $printing = $printings[0]
  Write-Host "3. card search OK ($($printing.card_name) — $($printing.set_code) #$($printing.card_number))"

  $cities = Invoke-RestMethod "$ApiUrl/cities"
  $cityId = if ($cities) { $cities[0].id } else { $null }

  $body = @{
    card_printing_id = $printing.id
    condition        = 'NM'
    price            = 4500
    description      = 'smoke test — se marca removed al final'
    city_id          = $cityId
  } | ConvertTo-Json
  $created = Invoke-RestMethod "$ApiUrl/listings" -Method Post -ContentType 'application/json' -Headers $headers -Body $body
  Write-Host "4. listing creado ($($created.id))"

  $active = Invoke-RestMethod "$ApiUrl/listings"
  if (-not ($active.data | Where-Object { $_.id -eq $created.id })) { throw 'el listing creado no aparece en GET /listings' }
  Write-Host '5. listing visible en el browse público'

  # OG previews: el HTML de un deep link del SPA debe traer og:title con la
  # carta (requiere backend con WEB_DIR; el driver lo setea en start)
  $og = (Invoke-WebRequest "$ApiUrl/l/$($created.id)" -UseBasicParsing).Content
  if ($og -notmatch 'og:title') { throw 'smoke: falta og:title en el index inyectado' }
  if ($og -notmatch [regex]::Escape($printing.card_name)) { throw "smoke: og:title no menciona $($printing.card_name)" }
  Write-Host '6. OG preview del listing OK (og:title con la carta)'

  $sellerPage = Invoke-RestMethod "$ApiUrl/sellers/$($auth.user.username ?? 'smoke')"
  if ($null -eq $sellerPage.profile.username) { throw 'smoke: /sellers/{username} sin profile' }
  Write-Host "7. pagina de vendedor OK (/sellers/$($sellerPage.profile.username))"

  Write-Host '--- smoke: UI (screenshots con el listing visible) ---'
  $wide   = Invoke-Shot "$WebUrl/" 1600 900 (Join-Path $ShotsDir 'smoke-browse-wide.png')
  $mobile = Invoke-Shot "$WebUrl/" 400 866 (Join-Path $ShotsDir 'smoke-browse-mobile.png')
  $detail = Invoke-Shot "$ApiUrl/l/$($created.id)" 1600 900 (Join-Path $ShotsDir 'smoke-detail-wide.png')

  # cleanup: sacar el listing de smoke del browse
  $patch = @{ status = 'removed' } | ConvertTo-Json
  Invoke-RestMethod "$ApiUrl/listings/$($created.id)" -Method Patch -ContentType 'application/json' -Headers $headers -Body $patch | Out-Null
  Write-Host '6. cleanup OK (listing marcado removed)'

  Write-Host ''
  Write-Host 'SMOKE PASSED. Screenshots:'
  Write-Host "  $wide"
  Write-Host "  $mobile"
  Write-Host "  $detail"
}

function Invoke-Status {
  Write-Host ("backend :8080 -> " + ($(if (Test-PortListening 8080) { 'LISTENING' } else { 'down' })))
  Write-Host ("web     :5003 -> " + ($(if (Test-PortListening 5003) { 'LISTENING' } else { 'down' })))
  $pids = Load-Pids
  if ($pids) { Write-Host "pids: backend=$($pids.backend) web=$($pids.web)" }
}

switch ($Command) {
  'start'  { Invoke-Start }
  'stop'   { Invoke-Stop }
  'smoke'  { Invoke-Smoke }
  'shot'   { Invoke-Shot $Url $Width $Height $Out | Out-Null }
  'status' { Invoke-Status }
}
