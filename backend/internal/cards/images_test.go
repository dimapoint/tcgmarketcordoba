package cards

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestProxyImagePath(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want string
		ok   bool
	}{
		{
			name: "url del CDN de Riot con query",
			in:   "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/abc123-744x1039.png?accountingTag=RB",
			want: "/card-images/abc123-744x1039.png",
			ok:   true,
		},
		{
			name: "url del CDN sin query",
			in:   "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/def.png",
			want: "/card-images/def.png",
			ok:   true,
		},
		{
			name: "otro host queda igual",
			in:   "https://example.com/foo.png",
			ok:   false,
		},
		{
			name: "subpath extra no matchea",
			in:   "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/sub/dir.png",
			ok:   false,
		},
	}
	for _, c := range cases {
		got, ok := proxyImagePath(c.in)
		if ok != c.ok || (ok && got != c.want) {
			t.Errorf("%s: proxyImagePath(%q) = (%q, %v), want (%q, %v)",
				c.name, c.in, got, ok, c.want, c.ok)
		}
	}
}

func TestSearchRewritesImageURLsToProxy(t *testing.T) {
	url := "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/abc123-744x1039.png?accountingTag=RB"
	h := &Handler{Store: &fakeStore{results: []Printing{{CardName: "Jinx", ImageURL: &url}}}}
	rec := httptest.NewRecorder()
	h.Search(rec, httptest.NewRequest("GET", "/cards/search?q=ji", nil))
	if !strings.Contains(rec.Body.String(), `"image_url":"/card-images/abc123-744x1039.png"`) {
		t.Fatalf("body = %s, want image_url proxied", rec.Body)
	}
}

func TestSearchLeavesNullImageURL(t *testing.T) {
	h := &Handler{Store: &fakeStore{results: []Printing{{CardName: "Jinx"}}}}
	rec := httptest.NewRecorder()
	h.Search(rec, httptest.NewRequest("GET", "/cards/search?q=ji", nil))
	if !strings.Contains(rec.Body.String(), `"image_url":null`) {
		t.Fatalf("body = %s, want image_url null", rec.Body)
	}
}

func newProxyMux(p *ImageProxy) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /card-images/{file}", p.Serve)
	return mux
}

func TestImageProxyStreamsUpstream(t *testing.T) {
	var gotPath, gotQuery string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath, gotQuery = r.URL.Path, r.URL.RawQuery
		w.Header().Set("Content-Type", "image/png")
		w.Write([]byte("PNGDATA"))
	}))
	defer upstream.Close()

	p := &ImageProxy{Upstream: upstream.URL + "/sanity/images/dsfx7636/game_data_live"}
	rec := httptest.NewRecorder()
	newProxyMux(p).ServeHTTP(rec, httptest.NewRequest("GET", "/card-images/abc.png", nil))

	if gotPath != "/sanity/images/dsfx7636/game_data_live/abc.png" {
		t.Fatalf("upstream path = %q", gotPath)
	}
	if gotQuery != "accountingTag=RB" {
		t.Fatalf("upstream query = %q", gotQuery)
	}
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d", rec.Code)
	}
	if body, _ := io.ReadAll(rec.Body); string(body) != "PNGDATA" {
		t.Fatalf("body = %q", body)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "image/png" {
		t.Fatalf("content-type = %q", ct)
	}
	if cc := rec.Header().Get("Cache-Control"); !strings.Contains(cc, "max-age") {
		t.Fatalf("cache-control = %q, want long max-age", cc)
	}
}

func TestImageProxyRejectsBadNames(t *testing.T) {
	// El mux ya limpia ".." y rechaza URLs malformadas; esto cubre la
	// validación propia del handler para nombres que igual lleguen.
	p := &ImageProxy{Upstream: "http://127.0.0.1:0"}
	for _, file := range []string{"..", "a/b.png", "con espacios.png", ".oculto", ""} {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest("GET", "/card-images/x", nil)
		req.SetPathValue("file", file)
		p.Serve(rec, req)
		if rec.Code != http.StatusNotFound {
			t.Errorf("file %q: code = %d, want 404", file, rec.Code)
		}
	}
}

func TestImageProxyUpstreamErrorIs404(t *testing.T) {
	upstream := httptest.NewServer(http.NotFoundHandler())
	defer upstream.Close()
	p := &ImageProxy{Upstream: upstream.URL}
	rec := httptest.NewRecorder()
	newProxyMux(p).ServeHTTP(rec, httptest.NewRequest("GET", "/card-images/nope.png", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}
