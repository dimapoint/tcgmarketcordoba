# Dev de un solo comando: backend Go (:8080) + Flutter web con hot reload (:5003).
# Uso: ./dev.ps1   |   r = hot reload, R = hot restart, q = salir (baja el backend)
$ErrorActionPreference = 'Stop'
$driver = Join-Path $PSScriptRoot '.claude/skills/run-tcgmarketcordoba/driver.ps1'

pwsh $driver start -BackendOnly
Write-Host ''
Write-Host 'Abrí http://localhost:5003 en tu browser.'
Write-Host 'r = hot reload | R = hot restart | q = salir'
Write-Host ''
try {
  flutter run -d web-server --web-port 5003 --web-hostname localhost
} finally {
  pwsh $driver stop
}
