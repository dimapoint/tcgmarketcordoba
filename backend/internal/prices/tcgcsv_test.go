package prices

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

const tcgcsvGroupsJSON = `{"totalItems":2,"success":true,"errors":[],"results":[
	{"groupId":24344,"name":"Origins","abbreviation":"OGN"},
	{"groupId":24560,"name":"Unleashed","abbreviation":"UNL"}]}`

func newTCGCsvServer(t *testing.T, hits *atomic.Int32, fail *atomic.Bool) *httptest.Server {
	t.Helper()
	mux := http.NewServeMux()
	mux.HandleFunc("/tcgplayer/89/groups", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, tcgcsvGroupsJSON)
	})
	mux.HandleFunc("/tcgplayer/89/24344/prices", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"success":true,"errors":[],"results":[
			{"productId":635366,"lowPrice":7.99,"midPrice":10.12,"highPrice":15.0,"marketPrice":8.64,"directLowPrice":null,"subTypeName":"Normal"},
			{"productId":635366,"lowPrice":20.0,"midPrice":25.0,"highPrice":40.0,"marketPrice":22.10,"directLowPrice":null,"subTypeName":"Foil"},
			{"productId":635367,"lowPrice":1.0,"midPrice":2.0,"highPrice":3.0,"marketPrice":null,"directLowPrice":null,"subTypeName":"Normal"}]}`)
	})
	mux.HandleFunc("/tcgplayer/89/24560/prices", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"success":true,"errors":[],"results":[
			{"productId":684492,"lowPrice":13.59,"midPrice":20.0,"highPrice":40.0,"marketPrice":15.26,"directLowPrice":null,"subTypeName":"Foil"}]}`)
	})
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		// tcgcsv devuelve 401 al User-Agent default de Go: exigir uno propio
		if ua := r.Header.Get("User-Agent"); !strings.HasPrefix(ua, "tcgmarketcordoba/") {
			t.Errorf("User-Agent = %q", ua)
		}
		if fail != nil && fail.Load() {
			http.Error(w, "boom", http.StatusInternalServerError)
			return
		}
		mux.ServeHTTP(w, r)
	}))
}

func TestTCGCsvPriceBySubtype(t *testing.T) {
	var hits atomic.Int32
	srv := newTCGCsvServer(t, &hits, nil)
	defer srv.Close()
	c := &TCGCsv{BaseURL: srv.URL}

	normal, err := c.Price(context.Background(), "635366", false)
	if err != nil || normal == nil || *normal != 8.64 {
		t.Fatalf("normal = %v, %v", normal, err)
	}
	foil, err := c.Price(context.Background(), "635366", true)
	if err != nil || foil == nil || *foil != 22.10 {
		t.Fatalf("foil = %v, %v", foil, err)
	}
	// producto de otro grupo (UNL) también entra al índice
	unl, err := c.Price(context.Background(), "684492", true)
	if err != nil || unl == nil || *unl != 15.26 {
		t.Fatalf("unl = %v, %v", unl, err)
	}
	// marketPrice null → sin dato
	if p, err := c.Price(context.Background(), "635367", false); err != nil || p != nil {
		t.Fatalf("sin market price = %v, %v", p, err)
	}
	// producto desconocido → sin dato, sin error
	if p, err := c.Price(context.Background(), "999999", false); err != nil || p != nil {
		t.Fatalf("desconocido = %v, %v", p, err)
	}
}

func TestTCGCsvCachesUntilTTL(t *testing.T) {
	var hits atomic.Int32
	srv := newTCGCsvServer(t, &hits, nil)
	defer srv.Close()

	now := time.Now()
	c := &TCGCsv{BaseURL: srv.URL, TTL: time.Hour, Now: func() time.Time { return now }}

	c.Price(context.Background(), "635366", false)
	first := hits.Load() // groups + 2 grupos = 3
	if first != 3 {
		t.Fatalf("hits tras primer fetch = %d, want 3", first)
	}
	c.Price(context.Background(), "684492", true)
	if hits.Load() != first {
		t.Errorf("segunda consulta no debería pegarle al server: %d", hits.Load())
	}

	now = now.Add(2 * time.Hour) // vence el TTL
	c.Price(context.Background(), "635366", false)
	if hits.Load() != first*2 {
		t.Errorf("tras vencer TTL debería refetchear: hits = %d, want %d", hits.Load(), first*2)
	}
}

func TestTCGCsvServesStaleOnError(t *testing.T) {
	var hits atomic.Int32
	var fail atomic.Bool
	srv := newTCGCsvServer(t, &hits, &fail)
	defer srv.Close()

	now := time.Now()
	c := &TCGCsv{BaseURL: srv.URL, TTL: time.Hour, Now: func() time.Time { return now }}

	if p, err := c.Price(context.Background(), "635366", false); err != nil || p == nil {
		t.Fatalf("warm-up: %v, %v", p, err)
	}

	fail.Store(true)
	now = now.Add(2 * time.Hour)
	p, err := c.Price(context.Background(), "635366", false)
	if err != nil || p == nil || *p != 8.64 {
		t.Fatalf("con caché vieja debería servir stale: %v, %v", p, err)
	}
}

func TestTCGCsvColdErrorPropagates(t *testing.T) {
	var hits atomic.Int32
	var fail atomic.Bool
	fail.Store(true)
	srv := newTCGCsvServer(t, &hits, &fail)
	defer srv.Close()

	c := &TCGCsv{BaseURL: srv.URL}
	if _, err := c.Price(context.Background(), "635366", false); err == nil {
		t.Fatal("sin caché y con server caído esperaba error")
	}
}
