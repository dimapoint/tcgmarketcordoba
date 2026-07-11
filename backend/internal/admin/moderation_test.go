package admin

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/buyorders"
	"tcgmarketcordoba/internal/listings"
)

type fakeListingMod struct {
	gotStatus, gotQuery string
	items               []listings.Listing
	statuses            map[string]string
}

func (f *fakeListingMod) AllAdmin(_ context.Context, status, query string) ([]listings.Listing, error) {
	f.gotStatus, f.gotQuery = status, query
	return f.items, nil
}

func (f *fakeListingMod) AdminUpdateStatus(_ context.Context, id, status string) error {
	if _, ok := f.statuses[id]; !ok {
		return listings.ErrNotFound
	}
	f.statuses[id] = status
	return nil
}

type fakeBuyOrderMod struct {
	gotStatus, gotQuery string
	items               []buyorders.BuyOrder
	statuses            map[string]string
}

func (f *fakeBuyOrderMod) AllAdmin(_ context.Context, status, query string) ([]buyorders.BuyOrder, error) {
	f.gotStatus, f.gotQuery = status, query
	return f.items, nil
}

func (f *fakeBuyOrderMod) AdminUpdateStatus(_ context.Context, id, status string) error {
	if _, ok := f.statuses[id]; !ok {
		return buyorders.ErrNotFound
	}
	f.statuses[id] = status
	return nil
}

// testMux replica el wiring de main.go para todas las rutas admin.
func testMux(h *Handler, store Store) *http.ServeMux {
	requireAdmin := func(fn http.HandlerFunc) http.Handler {
		return auth.Middleware(testTokens)(Require(store)(fn))
	}
	mux := http.NewServeMux()
	mux.Handle("GET /admin/stats", requireAdmin(h.Stats))
	mux.Handle("GET /admin/listings", requireAdmin(h.ListListings))
	mux.Handle("PATCH /admin/listings/{id}", requireAdmin(h.PatchListing))
	mux.Handle("GET /admin/buy-orders", requireAdmin(h.ListBuyOrders))
	mux.Handle("PATCH /admin/buy-orders/{id}", requireAdmin(h.PatchBuyOrder))
	return mux
}

func testModHandler() (*Handler, *fakeStore, *fakeListingMod, *fakeBuyOrderMod) {
	store := &fakeStore{admins: map[string]bool{"admin-1": true}}
	lm := &fakeListingMod{statuses: map[string]string{"l1": "active"}}
	bm := &fakeBuyOrderMod{statuses: map[string]string{"b1": "active"}}
	h := &Handler{Store: store, Listings: lm, BuyOrders: bm}
	return h, store, lm, bm
}

func adminDo(t *testing.T, mux *http.ServeMux, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	var req *http.Request
	if body == "" {
		req = httptest.NewRequest(method, path, nil)
	} else {
		req = httptest.NewRequest(method, path, strings.NewReader(body))
	}
	token, err := testTokens.Issue("admin-1")
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func TestListListingsPassesFilters(t *testing.T) {
	h, store, lm, _ := testModHandler()
	mux := testMux(h, store)
	rec := adminDo(t, mux, "GET", "/admin/listings?status=removed&q=kha", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	if lm.gotStatus != "removed" || lm.gotQuery != "kha" {
		t.Fatalf("filtros = (%q, %q)", lm.gotStatus, lm.gotQuery)
	}
	var out []listings.Listing
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
}

func TestListListingsRejectsInvalidStatus(t *testing.T) {
	h, store, _, _ := testModHandler()
	rec := adminDo(t, testMux(h, store), "GET", "/admin/listings?status=zombie", "")
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("code = %d, want 400", rec.Code)
	}
}

func TestPatchListingRemoves(t *testing.T) {
	h, store, lm, _ := testModHandler()
	rec := adminDo(t, testMux(h, store), "PATCH", "/admin/listings/l1",
		`{"status":"removed"}`)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	if lm.statuses["l1"] != "removed" {
		t.Fatalf("status = %q, want removed", lm.statuses["l1"])
	}
}

func TestPatchListingRejectsSold(t *testing.T) {
	// sold/fulfilled son del dueño, no del moderador.
	h, store, _, _ := testModHandler()
	rec := adminDo(t, testMux(h, store), "PATCH", "/admin/listings/l1",
		`{"status":"sold"}`)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("code = %d, want 400", rec.Code)
	}
}

func TestPatchListingNotFound(t *testing.T) {
	h, store, _, _ := testModHandler()
	rec := adminDo(t, testMux(h, store), "PATCH", "/admin/listings/nope",
		`{"status":"removed"}`)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}

func TestListBuyOrdersPassesFilters(t *testing.T) {
	h, store, _, bm := testModHandler()
	rec := adminDo(t, testMux(h, store), "GET", "/admin/buy-orders?status=fulfilled&q=jinx", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	if bm.gotStatus != "fulfilled" || bm.gotQuery != "jinx" {
		t.Fatalf("filtros = (%q, %q)", bm.gotStatus, bm.gotQuery)
	}
}

func TestPatchBuyOrderRestores(t *testing.T) {
	h, store, _, bm := testModHandler()
	bm.statuses["b1"] = "removed"
	rec := adminDo(t, testMux(h, store), "PATCH", "/admin/buy-orders/b1",
		`{"status":"active"}`)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	if bm.statuses["b1"] != "active" {
		t.Fatalf("status = %q, want active", bm.statuses["b1"])
	}
}

func TestAllAdminRoutesForbiddenForNonAdmin(t *testing.T) {
	h, store, _, _ := testModHandler()
	mux := testMux(h, store)
	routes := []struct{ method, path string }{
		{"GET", "/admin/stats"},
		{"GET", "/admin/listings"},
		{"PATCH", "/admin/listings/l1"},
		{"GET", "/admin/buy-orders"},
		{"PATCH", "/admin/buy-orders/b1"},
	}
	for _, rt := range routes {
		req := httptest.NewRequest(rt.method, rt.path, strings.NewReader(`{"status":"removed"}`))
		token, _ := testTokens.Issue("user-comun")
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		if rec.Code != http.StatusForbidden {
			t.Errorf("%s %s: code = %d, want 403", rt.method, rt.path, rec.Code)
		}
	}
}
