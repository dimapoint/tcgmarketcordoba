# Deploy a Fly.io: el Dockerfile buildea Flutter web + Go.
#   ./deploy.ps1                # usa https://tcgmarketcordoba.fly.dev
#   ./deploy.ps1 -AppUrl https://otra-url.fly.dev
param(
    [string]$AppUrl = "https://tcgmarketcordoba.fly.dev"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# GOOGLE_CLIENT_ID (público) se toma del .env local si existe, para que el
# botón "Continuar con Google" aparezca en el build de prod.
$googleClientId = ""
if (Test-Path .env) {
    $match = (Get-Content .env -Raw) -split "\r?\n" | Where-Object { $_ -match '^GOOGLE_CLIENT_ID=(.*)$' } | Select-Object -First 1
    if ($match -match '^GOOGLE_CLIENT_ID=(.*)$') {
        $googleClientId = $Matches[1].Trim()
    }
}

$deployArgs = @(
    "deploy",
    "--build-arg", "API_URL=$AppUrl"
)
if ($googleClientId) {
    $deployArgs += @("--build-arg", "GOOGLE_CLIENT_ID=$googleClientId")
}

flyctl @deployArgs
if ($LASTEXITCODE -ne 0) { throw "flyctl deploy falló" }

Write-Host "`nDeploy OK -> $AppUrl" -ForegroundColor Green
