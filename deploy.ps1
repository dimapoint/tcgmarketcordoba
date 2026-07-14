# Deploy a Fly.io: buildea Flutter web apuntando a la URL pública y sube la imagen.
#   ./deploy.ps1                # usa https://tcgmarketcordoba.fly.dev
#   ./deploy.ps1 -AppUrl https://otra-url.fly.dev
param(
    [string]$AppUrl = "https://tcgmarketcordoba.fly.dev"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# .env raíz es un asset bundleado (público): en producción API_URL = mismo origen.
# GOOGLE_CLIENT_ID (valor público) se conserva del .env local para que el botón
# "Continuar con Google" aparezca en el build de prod.
$envBackup = Get-Content .env -Raw
$buildEnv = @("API_URL=$AppUrl")
$buildEnv += ($envBackup -split "\r?\n") -match '^GOOGLE_CLIENT_ID='
Set-Content .env ($buildEnv -join "`n")
try {
    # flutter clean evita que .dart_tool/flutter_build quede con un
    # web_plugin_registrant.dart viejo (plugins nuevos no registrados en el build).
    flutter clean
    flutter build web --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build web falló" }

    # Guard: si el .env quedó mal (p.ej. porque quedó sobreescrito con un valor
    # de prod antes de correr este script), el bundle apuntaría a la URL vieja
    # y quedaría serviendo ese API_URL a todos los visitantes silenciosamente.
    $bundleEnv = Get-Content build/web/assets/.env -Raw
    if ($bundleEnv -notmatch [regex]::Escape("API_URL=$AppUrl")) {
        throw "build/web/assets/.env no tiene API_URL=$AppUrl - abortando deploy (bundle: $bundleEnv)"
    }
} finally {
    Set-Content .env $envBackup -NoNewline
}

flyctl deploy
if ($LASTEXITCODE -ne 0) { throw "flyctl deploy falló" }

Write-Host "`nDeploy OK -> $AppUrl" -ForegroundColor Green
