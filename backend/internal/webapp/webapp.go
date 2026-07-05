// Package webapp sirve el build web de Flutter (y archivos sueltos como
// el riot.txt de verificación) con fallback SPA: cualquier ruta que no
// sea un archivo existente devuelve index.html para que GoRouter resuelva.
package webapp

import (
	"net/http"
	"os"
	"path"
	"path/filepath"
)

func Handler(dir string) http.Handler {
	fs := http.FileServer(http.Dir(dir))
	index := filepath.Join(dir, "index.html")

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// path.Clean corta cualquier ../ antes de tocar el filesystem
		clean := path.Clean("/" + r.URL.Path)
		full := filepath.Join(dir, filepath.FromSlash(clean))

		if info, err := os.Stat(full); err == nil && !info.IsDir() {
			r.URL.Path = clean
			fs.ServeHTTP(w, r)
			return
		}
		http.ServeFile(w, r, index)
	})
}
