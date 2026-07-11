---
name: run-tcgmarketcordoba
description: Start tcgmarketcordoba (Go backend + Flutter web) locally for manual testing and hot-reload dev work. Use when asked to run, start, or dev-loop the app.
---

Marketplace P2P de cartas Riftbound: backend Go (`:8080`) + Flutter web con
hot reload (`:5003`). Un solo comando levanta todo: `./dev.ps1`.

Rutas relativas a la raíz del repo. Entorno verificado: Windows 11,
PowerShell 7, Go y Flutter ya instalados.

## Prerequisites

Ya presentes en esta máquina: `go`, `flutter`, `pwsh`.

**Requisito de datos:** `backend/.env` con `DATABASE_URL` y `JWT_SECRET`
(gitignored — template en `backend/.env.example`).

## Run

```powershell
./dev.ps1
```

Internamente: `.claude/skills/run-tcgmarketcordoba/driver.ps1 start -BackendOnly`
(compila y levanta el backend en background, espera `/health`) seguido de
`flutter run -d web-server --web-port 5003 --web-hostname localhost` en
foreground. Abrir **http://localhost:5003** a mano — Flutter no ejecuta
Dart hasta que una pestaña se conecta, aunque el puerto ya esté
escuchando.

Mientras corre: `r` = hot reload | `R` = hot restart | `q` = salir (baja
también el backend vía `driver.ps1 stop`).

Alternativa manual, sin hot reload (release-like):

```powershell
cd backend; go run .                                                           # terminal 1
flutter build web --release; python -m http.server 5003 --directory build/web  # terminal 2
```

`flutter run -d chrome` falla si Chrome ya está abierto; con `-d
web-server` hay que abrir el browser a mano.

## Test

```powershell
flutter test          # 26 tests, todos verdes (~20 s)
cd backend; go test ./...
```

## Gotchas

- **Salir sin pasar por `q` deja procesos huérfanos.** `flutter run -d
  web-server` lanza un `dartvm.exe` hijo que sobrevive si se mata el
  proceso padre desde afuera (cerrar la terminal, matar el wrapper sin
  matar el árbol completo) y sigue escuchando en `:5003`; lo mismo con
  el backend Go en `:8080` si no se pasa por `driver.ps1 stop`. Síntoma:
  `localhost:5003` responde con un build viejo aunque no haya ninguna
  sesión de dev visible. Diagnosticar con
  `pwsh .claude/skills/run-tcgmarketcordoba/driver.ps1 status` y, si
  hace falta, matar a mano el proceso que retiene el puerto:
  `Get-NetTCPConnection -LocalPort 5003 -State Listen | Select
  OwningProcess`.

## Troubleshooting

- **`backend no respondió /health en 30s`**: falta `backend/.env` o la
  `DATABASE_URL` no llega al pooler de Supabase. Ver logs corriendo
  `go run .` en foreground dentro de `backend/`.
