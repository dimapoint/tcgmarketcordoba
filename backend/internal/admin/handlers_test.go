package admin

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"tcgmarketcordoba/internal/auth"
)

type fakeStore struct {
	admins map[string]bool
	stats  Stats
}

func (f *fakeStore) IsAdmin(_ context.Context, userID string) (bool, error) {
	return f.admins[userID], nil
}

func (f *fakeStore) Stats(_ context.Context) (Stats, error) {
	return f.stats, nil
}

var testTokens = auth.TokenIssuer{Secret: []byte("test-secret"), TTL: time.Minute}

// protect arma la misma cadena que main.go: requireAuth + admin.Require.
func protect(store Store, h http.HandlerFunc) http.Handler {
	return auth.Middleware(testTokens)(Require(store)(h))
}

func authedReq(t *testing.T, method, path, userID string) *http.Request {
	t.Helper()
	req := httptest.NewRequest(method, path, nil)
	token, err := testTokens.Issue(userID)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	return req
}

func TestStatsRequiresToken(t *testing.T) {
	store := &fakeStore{admins: map[string]bool{}}
	h := &Handler{Store: store}
	rec := httptest.NewRecorder()
	protect(store, h.Stats).ServeHTTP(rec, httptest.NewRequest("GET", "/admin/stats", nil))
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("code = %d, want 401", rec.Code)
	}
}

func TestStatsForbiddenForNonAdmin(t *testing.T) {
	store := &fakeStore{admins: map[string]bool{}}
	h := &Handler{Store: store}
	rec := httptest.NewRecorder()
	protect(store, h.Stats).ServeHTTP(rec, authedReq(t, "GET", "/admin/stats","user-1"))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("code = %d, want 403, body = %s", rec.Code, rec.Body)
	}
	var res struct {
		Error string `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &res); err != nil {
		t.Fatal(err)
	}
	if res.Error != "solo para administradores" {
		t.Fatalf("error = %q", res.Error)
	}
}

func TestStatsOKForAdmin(t *testing.T) {
	store := &fakeStore{
		admins: map[string]bool{"admin-1": true},
		stats: Stats{
			Users: 10, ActiveListings: 5, ActiveBuyOrders: 3,
			NewUsers7d: 2, NewListings7d: 1, NewBuyOrders7d: 4,
		},
	}
	h := &Handler{Store: store}
	rec := httptest.NewRecorder()
	protect(store, h.Stats).ServeHTTP(rec, authedReq(t, "GET", "/admin/stats","admin-1"))
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	var got Stats
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got != store.stats {
		t.Fatalf("stats = %+v, want %+v", got, store.stats)
	}
}
