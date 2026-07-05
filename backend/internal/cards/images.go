package cards

import (
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"tcgmarketcordoba/internal/httpx"
)

// Las imágenes de carta viven en el CDN de Riot, que no manda headers CORS:
// Flutter web no puede cargarlas directo, así que la API las reescribe a
// /card-images/{file} y este proxy las sirve con nuestro CORS y cache largo.
const riotCDNPrefix = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/"

var imageFileRe = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)

// proxyImagePath convierte una URL del CDN de Riot en la ruta relativa del
// proxy ("/card-images/<file>"). Devuelve ok=false si la URL no es del CDN
// o el nombre de archivo no es un segmento simple.
func proxyImagePath(raw string) (string, bool) {
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
}

func (p *ImageProxy) Serve(w http.ResponseWriter, r *http.Request) {
	file := r.PathValue("file")
	if !imageFileRe.MatchString(file) {
		httpx.Error(w, http.StatusNotFound, "imagen no encontrada")
		return
	}
	upstream := strings.TrimSuffix(p.Upstream, "/")
	if upstream == "" {
		upstream = strings.TrimSuffix(riotCDNPrefix, "/")
	}
	client := p.Client
	if client == nil {
		client = &http.Client{Timeout: 30 * time.Second}
	}
	resp, err := client.Get(upstream + "/" + file + "?accountingTag=RB")
	if err != nil {
		httpx.Error(w, http.StatusBadGateway, "no se pudo obtener la imagen")
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		httpx.Error(w, http.StatusNotFound, "imagen no encontrada")
		return
	}
	if ct := resp.Header.Get("Content-Type"); ct != "" {
		w.Header().Set("Content-Type", ct)
	}
	// Los assets de Sanity van hasheados por contenido: cachear fuerte.
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	w.WriteHeader(http.StatusOK)
	io.Copy(w, resp.Body)
}
