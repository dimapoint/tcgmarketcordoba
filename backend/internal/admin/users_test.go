package admin

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

func usersMux(h *Handler) *http.ServeMux {
	requireAdmin := func(fn http.HandlerFunc) http.Handler {
		return auth.Middleware(testTokens)(Require(h.Store)(fn))
	}
	mux := http.NewServeMux()
	mux.Handle("GET /admin/users", requireAdmin(h.ListUsers))
	mux.Handle("PATCH /admin/users/{id}", requireAdmin(h.PatchUser))
	return mux
}

func doAs(t *testing.T, mux *http.ServeMux, userID, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	var req *http.Request
	if body == "" {
		req = httptest.NewRequest(method, path, nil)
	} else {
		req = httptest.NewRequest(method, path, strings.NewReader(body))
	}
	token, err := testTokens.Issue(userID)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func TestListUsersReturnsEnvelope(t *testing.T) {
	store := &fakeStore{admins: map[string]bool{"admin-1": true}}
	store.users = make([]AdminUser, 21)
	for i := range store.users {
		store.users[i] = AdminUser{ID: "u", CreatedAt: time.Now()}
	}
	h := &Handler{Store: store}
	rec := doAs(t, usersMux(h), "admin-1", "GET", "/admin/users?q=ana", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	if store.gotUserQuery != "ana" {
		t.Fatalf("query = %q, want ana", store.gotUserQuery)
	}
	if store.gotUserLimit != 21 {
		t.Fatalf("limit = %d, want 21 (limit+1)", store.gotUserLimit)
	}
	var out httpx.PageResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	var data []AdminUser
	if b, err := json.Marshal(out.Data); err == nil {
		json.Unmarshal(b, &data)
	}
	if len(data) != 20 {
		t.Fatalf("len(data) = %d, want 20", len(data))
	}
	if out.NextCursor == "" {
		t.Fatal("next_cursor vacío, esperaba uno")
	}
}

func TestListUsersForbiddenForNonAdmin(t *testing.T) {
	store := &fakeStore{admins: map[string]bool{}}
	h := &Handler{Store: store}
	rec := doAs(t, usersMux(h), "user-1", "GET", "/admin/users", "")
	if rec.Code != http.StatusForbidden {
		t.Fatalf("code = %d, want 403", rec.Code)
	}
}

func TestPatchUserSetsAdmin(t *testing.T) {
	store := &fakeStore{
		admins: map[string]bool{"admin-1": true},
		users:  []AdminUser{{ID: "u1", IsAdmin: false}},
	}
	h := &Handler{Store: store}
	rec := doAs(t, usersMux(h), "admin-1", "PATCH", "/admin/users/u1", `{"is_admin":true}`)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	if !store.users[0].IsAdmin {
		t.Fatal("is_admin no se actualizó")
	}
}

func TestPatchUserRejectsSelfChange(t *testing.T) {
	store := &fakeStore{
		admins: map[string]bool{"admin-1": true},
		users:  []AdminUser{{ID: "admin-1", IsAdmin: true}},
	}
	h := &Handler{Store: store}
	rec := doAs(t, usersMux(h), "admin-1", "PATCH", "/admin/users/admin-1", `{"is_admin":false}`)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("code = %d, want 400, body = %s", rec.Code, rec.Body)
	}
}

func TestPatchUserNotFound(t *testing.T) {
	store := &fakeStore{admins: map[string]bool{"admin-1": true}}
	h := &Handler{Store: store}
	rec := doAs(t, usersMux(h), "admin-1", "PATCH", "/admin/users/nope", `{"is_admin":true}`)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}

func TestPatchUserRejectsMalformedBody(t *testing.T) {
	store := &fakeStore{
		admins: map[string]bool{"admin-1": true},
		users:  []AdminUser{{ID: "u1"}},
	}
	h := &Handler{Store: store}
	rec := doAs(t, usersMux(h), "admin-1", "PATCH", "/admin/users/u1", `{}`)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("code = %d, want 400", rec.Code)
	}
}
