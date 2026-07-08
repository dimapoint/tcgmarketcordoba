package webapp

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const indexHTML = "<html><head><title>x</title></head><body>app</body></html>"

func setupDir(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	files := map[string]string{
		"index.html":         indexHTML,
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

func stubMeta(_ context.Context, path string) string {
	return `<meta property="og:title" content="META:` + path + `">`
}

func TestServesExistingFiles(t *testing.T) {
	h := Handler(setupDir(t), nil)

	for path, want := range map[string]string{
		"/riot.txt":           "riot-verification-token",
		"/main.dart.js":       "console.log('app')",
		"/assets/fonts/x.ttf": "font-bytes",
		"/":                   indexHTML,
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
	h := Handler(setupDir(t), nil)

	for _, path := range []string{"/login", "/publish", "/listings/abc-123"} {
		rec := get(t, h, path)
		if rec.Code != http.StatusOK {
			t.Errorf("GET %s = %d", path, rec.Code)
		}
		if rec.Body.String() != indexHTML {
			t.Errorf("GET %s should serve index.html, got %q", path, rec.Body.String())
		}
	}
}

func TestNoDirectoryTraversal(t *testing.T) {
	h := Handler(setupDir(t), nil)

	rec := get(t, h, "/../secret.txt")
	// debe caer al index (ruta SPA) o rechazar, nunca salir del directorio
	if rec.Code == http.StatusOK && rec.Body.String() != indexHTML {
		t.Errorf("traversal sirvió %q", rec.Body.String())
	}
}

func TestSPAFallbackInjectsMetaTags(t *testing.T) {
	h := Handler(setupDir(t), stubMeta)

	rec := get(t, h, "/listings/abc-123")
	body := rec.Body.String()
	if !strings.Contains(body, "META:/listings/abc-123") {
		t.Errorf("sin meta inyectada: %s", body)
	}
	if !strings.Contains(body, "</head>") || !strings.Contains(body, "<body>app</body>") {
		t.Errorf("index roto: %s", body)
	}
	if got := rec.Header().Get("Content-Type"); !strings.HasPrefix(got, "text/html") {
		t.Errorf("Content-Type = %q", got)
	}
}

func TestRootAlsoGetsMetaTags(t *testing.T) {
	h := Handler(setupDir(t), stubMeta)

	rec := get(t, h, "/")
	if !strings.Contains(rec.Body.String(), "META:/") {
		t.Errorf("la home también debe llevar tags: %s", rec.Body.String())
	}
}

func TestExistingFilesNotInjected(t *testing.T) {
	h := Handler(setupDir(t), stubMeta)

	rec := get(t, h, "/main.dart.js")
	if strings.Contains(rec.Body.String(), "META:") {
		t.Errorf("archivo real no debe inyectarse: %s", rec.Body.String())
	}
}

func TestNilMetaKeepsPlainIndex(t *testing.T) {
	h := Handler(setupDir(t), nil)

	rec := get(t, h, "/listings/abc")
	if strings.Contains(rec.Body.String(), "META:") {
		t.Errorf("nil meta no debe inyectar")
	}
}

func TestMissingHeadServesIndexAsIs(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "index.html"), []byte("<html>sin head</html>"), 0o644); err != nil {
		t.Fatal(err)
	}
	h := Handler(dir, stubMeta)

	rec := get(t, h, "/listings/abc")
	if rec.Code != http.StatusOK || rec.Body.String() != "<html>sin head</html>" {
		t.Errorf("sin </head> debe servir el index tal cual: %d %q", rec.Code, rec.Body.String())
	}
}
