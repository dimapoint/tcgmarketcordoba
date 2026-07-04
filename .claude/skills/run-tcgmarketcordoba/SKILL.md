---
name: run-tcgmarketcordoba
description: Build, run, and drive tcgmarketcordoba (Go backend + Flutter web). Use when asked to start the app, run a smoke test, take screenshots of the UI, verify a change end-to-end, or stop the servers.
---

Marketplace P2P de cartas Riftbound: backend Go (`:8080`) + Flutter web
servida estática (`:5003`). Se maneja todo con
`.claude/skills/run-tcgmarketcordoba/driver.ps1` — levanta ambos servicios,
corre un flujo E2E real contra la API (signup → buscar carta → publicar →
verificar en browse → cleanup) y saca screenshots con Chrome headless.

Todas las rutas son relativas a la raíz del repo. Entorno verificado:
Windows 11, PowerShell 7, Go, Flutter, Python y Chrome ya instalados.

## Prerequisites

Ya presentes en esta máquina (no hubo que instalar nada):
`go`, `flutter`, `python` (para `http.server`), `pwsh`, y Chrome en
`C:\Program Files\Google\Chrome\Application\chrome.exe` (path hardcodeado
en el driver).

**Requisito de datos:** `backend/.env` con `DATABASE_URL` y `JWT_SECRET`
(gitignored — template en `backend/.env.example`), y la DB con las cartas
de referencia cargadas (el smoke busca "jinx" en `card_printings`).

## Build

El driver builds solo lo que falta. Manual:

```powershell
cd backend; go build ./...        # check compilación backend
flutter build web --release      # bundle web → build/web (~40 s)
```

## Run (agent path)

```powershell
pwsh .claude/skills/run-tcgmarketcordoba/driver.ps1 start   # levanta todo
pwsh .claude/skills/run-tcgmarketcordoba/driver.ps1 smoke   # E2E + screenshots
pwsh .claude/skills/run-tcgmarketcordoba/driver.ps1 stop    # baja todo
```

| comando | qué hace |
|---|---|
| `start` | `go build` → server.exe en background (`:8080`, espera `/health`), sirve `build/web` en `:5003`. Con `-Build` fuerza rebuild de flutter web. Reusa puertos ya ocupados. |
| `smoke` | Flujo E2E completo: health → signin/signup usuario `smoke@tcgsmoke.local` → `GET /cards/search?q=jinx` (`-Query` para otra carta) → `POST /listings` → verifica que aparece en `GET /listings` → screenshots browse (1600×900 y 400×866) y detalle → `PATCH status=removed` (cleanup). Termina con `SMOKE PASSED`. |
| `shot` | Screenshot arbitrario: `-Url http://localhost:5003/ -Width 1600 -Height 900 -Out ruta.png` |
| `status` | Muestra si `:8080` / `:5003` están escuchando y los PIDs manejados. |
| `stop` | Mata los procesos que `start` lanzó (PIDs en `%TEMP%\tcgmarket-run\pids.json`). |

Screenshots → `%TEMP%\tcgmarket-run\shots\`. Estado del driver →
`%TEMP%\tcgmarket-run\`.

**Después de cambiar código Flutter:** `start -Build` (o
`flutter build web --release` a mano) — el server estático no recompila.
Después de cambiar el backend: `stop` + `start` (recompila siempre).

Rutas útiles para `shot`: `/#/listings/<id>` (detalle), `/#/sign-in`.
GoRouter usa hash strategy, el `#` es necesario.

## Run (human path)

```powershell
./dev.ps1    # backend + flutter run -d web-server con hot reload en :5003
             # r = hot reload | R = hot restart | q = salir (baja el backend)
```

Internamente usa `driver.ps1 start -BackendOnly` y al salir hace `stop`.
Alternativa manual (release-like, sin hot reload):

```powershell
cd backend; go run .                                  # terminal 1
python -m http.server 5003 --directory build/web      # terminal 2
# abrir http://localhost:5003 — Ctrl-C para frenar
```

`flutter run -d chrome` falla si Chrome ya está abierto; con
`-d web-server` hay que abrir el browser a mano (no ejecuta Dart hasta
que una pestaña se conecta).

## Test

```powershell
flutter test          # 24 tests, todos verdes (~20 s)
cd backend; go test ./...
```

## Gotchas

- **Chrome headless sin `--user-data-dir` propio falla silencioso** si el
  Chrome del usuario está abierto: sale sin error y sin PNG. El driver usa
  un perfil aislado en `%TEMP%\tcgmarket-run\chrome-profile`.
- **El PNG aparece DESPUÉS de que `chrome.exe` retorna** — el launcher se
  desprende del proceso real. Hay que esperar el archivo (el driver hace
  poll hasta 30 s). Chequear `Test-Path` inmediatamente = falso negativo.
- **PowerShell parte `--flag=(expr)` y `--window-size=$W,$H` en argumentos
  separados** (la coma arma un array). Pasar los args de Chrome como array
  de strings ya interpolados.
- **`/cards/search` devuelve `[]` con menos de 2 caracteres** de query
  (guard en `backend/internal/cards/cards.go`). `q=a` parece "sin datos"
  pero es el guard.
- **El smoke escribe en la DB real** (Supabase hosted). Mitigación: un solo
  usuario fijo `smoke@tcgsmoke.local` (signup solo la primera vez) y el
  listing se marca `removed` al final. Si el smoke muere a mitad, quedará
  un listing activo huérfano: `PATCH /listings/<id>` con
  `{"status":"removed"}` autenticado como el usuario smoke lo limpia.
- **El tema de los screenshots sigue el tema de Windows** (la app usa
  `ThemeMode.system`). Con Windows en oscuro se captura el tema Hextech;
  no encontré flag de Chrome headless para forzar claro.

## Troubleshooting

- **`backend no respondió /health en 30s`**: falta `backend/.env` o la
  `DATABASE_URL` no llega al pooler de Supabase. Ver logs corriendo
  `go run .` en foreground dentro de `backend/`.
- **`sin resultados para 'jinx'`**: la DB no tiene los datos de referencia
  de cartas. Aplicar las migraciones/seed de `supabase/migrations/`.
- **Screenshot en blanco**: subir `--virtual-time-budget` (el driver usa
  15000 ms; Flutter web con CanvasKit tarda en pintar el primer frame).
