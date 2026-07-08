# Compartir en grupos: previews de WhatsApp, página de vendedor y botones de compartir

**Fecha:** 2026-07-07
**Objetivo:** atraer usuarios nuevos vía los grupos locales (WhatsApp/Facebook) cerrando el loop
compartir → preview lindo → landing pública → registrarse para contactar.

## Contexto

El browse (`/`), el detalle de listados (`/listings/{id}`) y la sección Busco (`/wanted`,
`/buy-orders/{id}`) ya son públicos (solo `/post`, `/wanted/new`, `/my-listings` y `/profile`
requieren login). Pero un link compartido en WhatsApp hoy se ve como un link pelado: Flutter web
renderiza en canvas y el crawler de WhatsApp no ve contenido. Además no hay ningún botón de
compartir en la app, ni una página que agrupe todo lo de un vendedor.

Las unidades de compartir que importan (validadas con el usuario): **un listado puntual**,
**la "carpeta" completa de un vendedor** y **una búsqueda ("Busco X")**. La página pública por
carta quedó explícitamente fuera de alcance.

## Alcance

Tres piezas independientes, construibles y mergeables por separado:

### 1. Previews Open Graph (backend, `internal/webapp`)

El handler SPA (`webapp.Handler`) hoy sirve `index.html` para toda ruta que no es un archivo.
Se extiende para inyectar meta tags Open Graph en el `<head>` según la ruta, antes de servir:

- Al construir el handler se lee `index.html` una vez y se parte en el `</head>` (cache en
  memoria; el build de Flutter no cambia en runtime). Por request: `prefijo + tags + sufijo`.
- El navegador ignora los tags y Flutter carga normal; el crawler de WhatsApp solo lee los tags.
  No hay detección de user-agent: una sola respuesta sirve para ambos.

Tags por ruta:

| Ruta | og:title | og:description | og:image |
|---|---|---|---|
| `/listings/{id}` | `"[Carta] — $[precio] \| TCG Market Córdoba"` | `"Vende [username] en [ciudad] · [condición][ · Foil]"` | primera foto del listado; si no tiene, imagen de catálogo de la carta vía proxy `?w=600` |
| `/buy-orders/{id}` | `"Busco: [carta] \| TCG Market Córdoba"` | `"[username] paga hasta $[max_price][ · cantidad N]"` | imagen de catálogo de la carta vía proxy `?w=600`; si no hay, logo |
| `/u/{username}` | `"Cartas de [username] en Córdoba"` | `"[N] en venta · [M] búsquedas activas"` | logo del sitio |
| resto | tags genéricos del sitio | — | logo del sitio |

Reglas:

- Siempre se emiten `og:title`, `og:description`, `og:image`, `og:url`, `og:type=website` y
  `og:site_name=TCG Market Córdoba`.
- **Cualquier error degrada a tags genéricos, nunca a un 500**: store caído, ID inexistente,
  UUID inválido, timeout (~1 s por consulta). Un preview feo jamás rompe la app.
- Todo valor interpolado pasa por `html.EscapeString` (los nombres de carta y usernames son
  input externo).
- `og:image` y `og:url` exigen URL absoluta → nueva variable de config **`PUBLIC_URL`**
  (default `http://localhost:8080` para dev; en Fly será `https://<app>.fly.dev`). Las fotos de
  listado ya son URLs absolutas de Supabase Storage y se usan tal cual; las imágenes de catálogo
  son rutas relativas del proxy (`/card-images/...`) y se prefijan con `PUBLIC_URL`.
- Para exponer la imagen de catálogo en listados: `selectListing` agrega `cp.image_url`, el
  modelo `Listing` suma `card_image_url` (reescrita a ruta de proxy con el mismo mecanismo que
  usa `cards.Search`, exportando `proxyImagePath` como `cards.ProxyImagePath`). El campo también
  queda disponible para el frontend (aditivo, no rompe nada).

### 2. Página pública de vendedor

**Backend:** nuevo endpoint público `GET /sellers/{username}` →

```json
{
  "profile": {"username": "...", "city": "..."},
  "listings": [ ...Listing activos... ],
  "buy_orders": [ ...BuyOrder activos... ]
}
```

- Username inexistente → 404 `{"error": "vendedor no encontrado"}`.
- Solo publicaciones con status `active`.
- **No** expone datos de contacto: esos siguen detrás de `GET /profiles/{id}/contacts` como hoy.
- Métodos de store nuevos: `listings.Store.ActiveBySeller(ctx, username)` y
  `buyorders.Store.ActiveByBuyer(ctx, username)` (filtro por `p.username` + status active), y
  lookup de perfil por username.
- Handler en paquete nuevo `internal/sellers`, con interfaces estrechas y tests contra fakes,
  siguiendo el patrón del resto de los feature packages.

**Flutter:** ruta pública `/u/:username` (no entra en `_protectedPrefixes`) con pantalla nueva:

- Header con username y ciudad.
- Sección "Vende" (reúsa las cards de listado existentes) y sección "Busca" (reúsa las de
  búsqueda). Tap navega al detalle correspondiente.
- Estado vacío si no tiene publicaciones activas ("todavía no publicó nada"); la página existe
  igual.
- Username inexistente → pantalla "vendedor no encontrado" con botón a la home (mismo patrón
  que el detalle de listado inexistente).
- Repository nuevo (`ApiSellerRepository`) sobre `ApiClient`, con interfaz abstracta como el
  resto.

### 3. Botones de compartir (Flutter)

- **Detalle de listado** y **detalle de búsqueda**: botón compartir que abre el share nativo
  (Web Share API vía `share_plus`) con texto pre-armado en español + link; si no está
  disponible, fallback a `https://wa.me/?text=<encoded>` y opción "copiar link"
  (`Clipboard.setData`, no puede fallar por red).
- **Mis Publicaciones**: acción "Compartir mi carpeta" que comparte `/u/{mi-username}`.
- Textos:
  - Listado: `"Vendo [Carta] ([Foil, ]NM) a $[precio] en TCG Market Córdoba 👉 [url]"`
  - Búsqueda: `"Busco [Carta] — pago hasta $[precio] · TCG Market Córdoba 👉 [url]"`
  - Carpeta: `"Mis cartas en venta en TCG Market Córdoba 👉 [url]"`
- El armado de texto y URL es una función pura testeable. La URL base sale del origin actual
  del navegador (web) — no hardcodear el dominio.
- `share_plus` es la única dependencia nueva del proyecto.

## Manejo de errores

- OG tags: degradación a genéricos ante cualquier fallo (regla central, testeada).
- Página de vendedor: 404 con mensaje en español; estado vacío no es error.
- Compartir: el fallback de copiar link siempre está disponible.

## Testing (TDD por paquete, como en todo el repo)

- `internal/webapp`: con resolvers/stores fake — ruta de listado inyecta título/imagen
  correctos y escapados, ruta desconocida inyecta genéricos, error de store degrada a
  genéricos, el fallback SPA sigue intacto (extiende el test existente).
- `internal/sellers` + stores: 200 con datos, 404 username inexistente, solo activos.
- `internal/config`: `PUBLIC_URL` con default.
- Flutter: `computeRedirect` confirma `/u/x` pública; widget test de la pantalla de vendedor
  (secciones, estado vacío, no encontrado); test unitario del armado de texto/URL de compartir.
- E2E: el smoke del driver agrega un paso que verifica que `GET /listings/{id}` (HTML)
  contiene `og:title`.

## Ajuste durante implementación: path URLs y deep links cortos

Al implementar se detectó que la app usaba **hash URLs** (`/#/listings/x`), lo que invalidaba
la premisa del feature: los crawlers descartan el fragment (siempre verían tags genéricos) y
un link con path real `/listings/{id}` lo atiende la ruta JSON de la API, no el SPA.

Solución aplicada:

- `usePathUrlStrategy()` en `main.dart` (no-op fuera de web).
- Deep links compartibles cortos y libres de colisión con la API: **`/l/{id}`** (listado),
  **`/b/{id}`** (búsqueda), `/u/{username}` (vendedor). GoRouter mantiene `/listings/:id` y
  `/buy-orders/:id` como redirects client-side.
- `ogmeta` resuelve `/l/`, `/b/` y `/u/`; los botones de compartir arman URLs con esos paths.

## Fuera de alcance

Página pública por carta, SEO/sitemap, Google OAuth (PR #3 sigue su camino aparte),
analytics de clicks en links compartidos.
