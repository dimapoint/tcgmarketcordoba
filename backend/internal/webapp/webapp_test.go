package webapp

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func setupDir(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	files := map[string]string{
		"index.html":         "<html>app</html>",
		"riot.txt":           "riot-verification-token",
		"main.dart.js":       "console.log('app')",
		"assets/fonts/x.ttf": "font-bytes",
	}
	for name, content := range files {
		path := filepath.Join(dir, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func get(t *testing.T, h http.Handler, path string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestServesExistingFiles(t *testing.T) {
	h := Handler(setupDir(t))

	for path, want := range map[string]string{
		"/riot.txt":           "riot-verification-token",
		"/main.dart.js":       "console.log('app')",
		"/assets/fonts/x.ttf": "font-bytes",
		"/":                   "<html>app</html>",
	} {
		rec := get(t, h, path)
		if rec.Code != http.StatusOK {
			t.Errorf("GET %s = %d", path, rec.Code)
		}
		if rec.Body.String() != want {
			t.Errorf("GET %s body = %q, want %q", path, rec.Body.String(), want)
		}
	}
}

func TestSPARoutesFallBackToIndex(t *testing.T) {
	h := Handler(setupDir(t))

	for _, path := range []string{"/login", "/publish", "/listings/abc-123"} {
		rec := get(t, h, path)
		if rec.Code != http.StatusOK {
			t.Errorf("GET %s = %d", path, rec.Code)
		}
		if rec.Body.String() != "<html>app</html>" {
			t.Errorf("GET %s should serve index.html, got %q", path, rec.Body.String())
		}
	}
}

func TestNoDirectoryTraversal(t *testing.T) {
	h := Handler(setupDir(t))

	rec := get(t, h, "/../secret.txt")
	// debe caer al index (ruta SPA) o rechazar, nunca salir del directorio
	if rec.Code == http.StatusOK && rec.Body.String() != "<html>app</html>" {
		t.Errorf("traversal sirvió %q", rec.Body.String())
	}
}
