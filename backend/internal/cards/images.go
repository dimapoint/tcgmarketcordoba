package cards

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"tcgmarketcordoba/internal/httpx"
)

// Las imágenes de carta viven en el CDN de Riot, que no manda headers CORS:
// Flutter web no puede cargarlas directo, así que la API las reescribe a
// /card-images/{file} y este proxy las sirve con nuestro CORS y cache largo.
const riotCDNPrefix = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/"

const maxImageWidth = 2048

var imageFileRe = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)

// ProxyImagePath convierte una URL del CDN de Riot en la ruta relativa del
// proxy ("/card-images/<file>"). Devuelve ok=false si la URL no es del CDN
// o el nombre de archivo no es un segmento simple.
func ProxyImagePath(raw string) (string, bool) {
	rest, found := strings.CutPrefix(raw, riotCDNPrefix)
	if !found {
		return "", false
	}
	if i := strings.IndexByte(rest, '?'); i >= 0 {
		rest = rest[:i]
	}
	if !imageFileRe.MatchString(rest) {
		return "", false
	}
	return "/card-images/" + rest, true
}

type ImageProxy struct {
	Upstream string       // base sin barra final; vacío = CDN de Riot
	Client   *http.Client // nil = client con timeout de 30 s
	CacheDir string       // vacío = sin cache en disco
}

// Serve responde /card-images/{file}?w=<ancho opcional>. El CDN (Sanity)
// redimensiona server-side con w=, así los pickers piden miniaturas de
// ~50 KB en vez del PNG completo de ~900 KB.
func (p *ImageProxy) Serve(w http.ResponseWriter, r *http.Request) {
	file := r.PathValue("file")
	if !imageFileRe.MatchString(file) {
		httpx.Error(w, http.StatusNotFound, "imagen no encontrada")
		return
	}
	width := 0
	if n, err := strconv.Atoi(r.URL.Query().Get("w")); err == nil && n > 0 && n <= maxImageWidth {
		width = n
	}

	cachePath := ""
	if p.CacheDir != "" {
		name := file
		if width > 0 {
			name = fmt.Sprintf("w%d-%s", width, file)
		}
		cachePath = filepath.Join(p.CacheDir, name)
		if _, err := os.Stat(cachePath); err == nil {
			w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
			http.ServeFile(w, r, cachePath)
			return
		}
	}

	upstream := strings.TrimSuffix(p.Upstream, "/")
	if upstream == "" {
		upstream = strings.TrimSuffix(riotCDNPrefix, "/")
	}
	url := upstream + "/" + file + "?accountingTag=RB"
	if width > 0 {
		url += "&w=" + strconv.Itoa(width)
	}
	client := p.Client
	if client == nil {
		client = &http.Client{Timeout: 30 * time.Second}
	}
	resp, err := client.Get(url)
	if err != nil {
		httpx.Error(w, http.StatusBadGateway, "no se pudo obtener la imagen")
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		httpx.Error(w, http.StatusNotFound, "imagen no encontrada")
		return
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 20<<20))
	if err != nil {
		httpx.Error(w, http.StatusBadGateway, "no se pudo obtener la imagen")
		return
	}

	if cachePath != "" {
		writeCacheFile(p.CacheDir, cachePath, body)
	}

	if ct := resp.Header.Get("Content-Type"); ct != "" {
		w.Header().Set("Content-Type", ct)
	}
	// Los assets de Sanity van hasheados por contenido: cachear fuerte.
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}

// writeCacheFile guarda best-effort: un fallo de disco no debe romper la
// respuesta. Escribe a un temporal y renombra para no servir a medias.
func writeCacheFile(dir, path string, body []byte) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return
	}
	tmp, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return
	}
	if _, err := tmp.Write(body); err != nil {
		tmp.Close()
		os.Remove(tmp.Name())
		return
	}
	tmp.Close()
	if err := os.Rename(tmp.Name(), path); err != nil {
		os.Remove(tmp.Name())
	}
}
