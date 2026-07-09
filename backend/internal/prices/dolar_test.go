package prices

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

func newDolarServer(t *testing.T, hits *atomic.Int32, fail *atomic.Bool) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		if fail != nil && fail.Load() {
			http.Error(w, "boom", http.StatusInternalServerError)
			return
		}
		if r.URL.Path != "/v1/dolares/blue" {
			http.NotFound(w, r)
			return
		}
		fmt.Fprint(w, `{"moneda":"USD","casa":"blue","nombre":"Blue","compra":1490,"venta":1510,"fechaActualizacion":"2026-07-08T20:58:00.000Z"}`)
	}))
}

func TestDolarBlueVenta(t *testing.T) {
	var hits atomic.Int32
	srv := newDolarServer(t, &hits, nil)
	defer srv.Close()

	c := &DolarAPI{BaseURL: srv.URL}
	rate, err := c.Rate(context.Background())
	if err != nil || rate != 1510 {
		t.Fatalf("rate = %v, %v (want venta 1510)", rate, err)
	}
}

func TestDolarCachesUntilTTL(t *testing.T) {
	var hits atomic.Int32
	srv := newDolarServer(t, &hits, nil)
	defer srv.Close()

	now := time.Now()
	c := &DolarAPI{BaseURL: srv.URL, TTL: time.Hour, Now: func() time.Time { return now }}
	c.Rate(context.Background())
	c.Rate(context.Background())
	if hits.Load() != 1 {
		t.Errorf("hits = %d, want 1 (cacheado)", hits.Load())
	}
	now = now.Add(2 * time.Hour)
	c.Rate(context.Background())
	if hits.Load() != 2 {
		t.Errorf("hits tras TTL = %d, want 2", hits.Load())
	}
}

func TestDolarServesStaleOnError(t *testing.T) {
	var hits atomic.Int32
	var fail atomic.Bool
	srv := newDolarServer(t, &hits, &fail)
	defer srv.Close()

	now := time.Now()
	c := &DolarAPI{BaseURL: srv.URL, TTL: time.Hour, Now: func() time.Time { return now }}
	c.Rate(context.Background())

	fail.Store(true)
	now = now.Add(2 * time.Hour)
	rate, err := c.Rate(context.Background())
	if err != nil || rate != 1510 {
		t.Fatalf("con caché vieja debería servir stale: %v, %v", rate, err)
	}
}

func TestDolarColdErrorPropagates(t *testing.T) {
	var hits atomic.Int32
	var fail atomic.Bool
	fail.Store(true)
	srv := newDolarServer(t, &hits, &fail)
	defer srv.Close()

	c := &DolarAPI{BaseURL: srv.URL}
	if _, err := c.Rate(context.Background()); err == nil {
		t.Fatal("sin caché y con server caído esperaba error")
	}
}
