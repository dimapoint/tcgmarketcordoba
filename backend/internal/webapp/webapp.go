// Package webapp sirve el build web de Flutter (y archivos sueltos como
// el riot.txt de verificación) con fallback SPA: cualquier ruta que no
// sea un archivo existente devuelve index.html para que GoRouter resuelva.
// Si se pasa una MetaFunc, inyecta sus meta tags (Open Graph) antes del
// </head> del index — el navegador los ignora, los crawlers de WhatsApp
// y Facebook los leen para armar el preview del link.
package webapp

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
)

// MetaFunc genera el bloque de meta tags para una ruta. No debe fallar:
// ante cualquier problema devuelve tags genéricos (ver internal/ogmeta).
type MetaFunc func(ctx context.Context, path string) string

func Handler(dir string, meta MetaFunc) http.Handler {
	fs := http.FileServer(http.Dir(dir))
	index := filepath.Join(dir, "index.html")

	// El build de Flutter no cambia en runtime: se lee y parte una sola vez.
	var head, tail []byte
	if meta != nil {
		if data, err := os.ReadFile(index); err == nil {
			if i := bytes.Index(data, []byte("</head>")); i >= 0 {
				head, tail = data[:i], data[i:]
			}
		}
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// path.Clean corta cualquier ../ antes de tocar el filesystem
		clean := path.Clean("/" + r.URL.Path)
		full := filepath.Join(dir, filepath.FromSlash(clean))

		if info, err := os.Stat(full); err == nil && !info.IsDir() {
			r.URL.Path = clean
			fs.ServeHTTP(w, r)
			return
		}
		if head == nil {
			http.ServeFile(w, r, index)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write(head)
		io.WriteString(w, meta(r.Context(), clean))
		w.Write(tail)
	})
}
