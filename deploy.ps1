# Deploy a Fly.io: buildea Flutter web apuntando a la URL pública y sube la imagen.
#   ./deploy.ps1                # usa https://tcgmarketcordoba.fly.dev
#   ./deploy.ps1 -AppUrl https://otra-url.fly.dev
param(
    [string]$AppUrl = "https://tcgmarketcordoba.fly.dev"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# .env raíz es un asset bundleado (público): en producción API_URL = mismo origen
$envBackup = Get-Content .env -Raw
Set-Content .env "API_URL=$AppUrl"
try {
    flutter build web --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build web falló" }
} finally {
    Set-Content .env $envBackup -NoNewline
}

flyctl deploy
if ($LASTEXITCODE -ne 0) { throw "flyctl deploy falló" }

Write-Host "`nDeploy OK -> $AppUrl" -ForegroundColor Green
