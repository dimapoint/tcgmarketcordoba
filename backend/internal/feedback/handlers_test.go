package feedback

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"tcgmarketcordoba/internal/auth"
)

type fakeStore struct {
	created   []Feedback
	all       []Feedback
	err       error
	lastUser  string
	gotStatus string
	statuses  map[string]string
	deleted   []string
}

func (f *fakeStore) Create(_ context.Context, userID, category, message string) error {
	if f.err != nil {
		return f.err
	}
	f.lastUser = userID
	f.created = append(f.created, Feedback{UserID: userID, Category: category, Message: message})
	return nil
}

func (f *fakeStore) List(_ context.Context, status string) ([]Feedback, error) {
	f.gotStatus = status
	if f.err != nil {
		return nil, f.err
	}
	return f.all, nil
}

func (f *fakeStore) UpdateStatus(_ context.Context, id, status string) error {
	if _, ok := f.statuses[id]; !ok {
		return ErrNotFound
	}
	f.statuses[id] = status
	return nil
}

func (f *fakeStore) Delete(_ context.Context, id string) error {
	if _, ok := f.statuses[id]; !ok {
		return ErrNotFound
	}
	delete(f.statuses, id)
	f.deleted = append(f.deleted, id)
	return nil
}

func authedReq(method, target, body string) *http.Request {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("user-1")
	var r *http.Request
	if body == "" {
		r = httptest.NewRequest(method, target, nil)
	} else {
		r = httptest.NewRequest(method, target, strings.NewReader(body))
	}
	r.Header.Set("Authorization", "Bearer "+tok)
	return r
}

func serveAuthed(h http.HandlerFunc, r *http.Request) *httptest.ResponseRecorder {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	rec := httptest.NewRecorder()
	auth.Middleware(issuer)(h).ServeHTTP(rec, r)
	return rec
}

func TestCreateStoresFeedbackFromJWTUser(t *testing.T) {
	store := &fakeStore{}
	h := &Handler{Store: store}
	rec := serveAuthed(h.Create, authedReq("POST", "/feedback",
		`{"category":"bug","message":"algo se rompió"}`))
	if rec.Code != http.StatusCreated {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	if store.lastUser != "user-1" {
		t.Fatalf("user = %q, want user-1 from JWT", store.lastUser)
	}
	if len(store.created) != 1 || store.created[0].Category != "bug" ||
		store.created[0].Message != "algo se rompió" {
		t.Fatalf("created = %+v", store.created)
	}
}

func TestCreateRejectsInvalidCategory(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	rec := serveAuthed(h.Create, authedReq("POST", "/feedback",
		`{"category":"spam","message":"hola"}`))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("code = %d, want 400", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "categoría inválida") {
		t.Fatalf("body = %s", rec.Body)
	}
}

func TestCreateRejectsEmptyAndTooLongMessage(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	for name, msg := range map[string]string{
		"empty":    "",
		"blank":    "   ",
		"too long": strings.Repeat("a", 2001),
	} {
		body, _ := json.Marshal(map[string]string{"category": "bug", "message": msg})
		rec := serveAuthed(h.Create, authedReq("POST", "/feedback", string(body)))
		if rec.Code != http.StatusBadRequest {
			t.Errorf("%s: code = %d, want 400", name, rec.Code)
		}
	}
}

func TestCreateStoreError500(t *testing.T) {
	h := &Handler{Store: &fakeStore{err: errors.New("boom")}}
	rec := serveAuthed(h.Create, authedReq("POST", "/feedback",
		`{"category":"otro","message":"hola"}`))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("code = %d, want 500", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "error interno") {
		t.Fatalf("body = %s", rec.Body)
	}
}

func TestListReturnsAllFeedback(t *testing.T) {
	h := &Handler{Store: &fakeStore{all: []Feedback{
		{ID: "f1", Username: "dimar", Category: "bug", Message: "x"},
	}}}
	rec := serveAuthed(h.List, authedReq("GET", "/admin/feedback", ""))
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	var out []Feedback
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if len(out) != 1 || out[0].Username != "dimar" || out[0].Category != "bug" {
		t.Fatalf("unexpected body: %s", rec.Body)
	}
}

func TestEndpointsRequireAuth(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	for name, fn := range map[string]http.HandlerFunc{
		"create": h.Create, "list": h.List, "patch": h.Patch, "delete": h.Delete,
	} {
		rec := serveAuthed(fn, httptest.NewRequest("GET", "/feedback", nil))
		if rec.Code != http.StatusUnauthorized {
			t.Errorf("%s: code = %d, want 401 sin token", name, rec.Code)
		}
	}
}

func TestListRejectsInvalidStatus(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	rec := serveAuthed(h.List, authedReq("GET", "/admin/feedback?status=zombie", ""))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("code = %d, want 400", rec.Code)
	}
}

func TestListPassesStatusFilter(t *testing.T) {
	store := &fakeStore{}
	h := &Handler{Store: store}
	rec := serveAuthed(h.List, authedReq("GET", "/admin/feedback?status=resuelto", ""))
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	if store.gotStatus != "resuelto" {
		t.Fatalf("status = %q, want resuelto", store.gotStatus)
	}
}

func TestPatchMarksResolved(t *testing.T) {
	store := &fakeStore{statuses: map[string]string{"f1": "nuevo"}}
	h := &Handler{Store: store}
	req := authedReq("PATCH", "/admin/feedback/f1", `{"status":"resuelto"}`)
	req.SetPathValue("id", "f1")
	rec := serveAuthed(h.Patch, req)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	if store.statuses["f1"] != "resuelto" {
		t.Fatalf("status = %q, want resuelto", store.statuses["f1"])
	}
}

func TestPatchRejectsInvalidStatus(t *testing.T) {
	h := &Handler{Store: &fakeStore{statuses: map[string]string{"f1": "nuevo"}}}
	req := authedReq("PATCH", "/admin/feedback/f1", `{"status":"zombie"}`)
	req.SetPathValue("id", "f1")
	rec := serveAuthed(h.Patch, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("code = %d, want 400", rec.Code)
	}
}

func TestPatchNotFound(t *testing.T) {
	h := &Handler{Store: &fakeStore{statuses: map[string]string{}}}
	req := authedReq("PATCH", "/admin/feedback/nope", `{"status":"resuelto"}`)
	req.SetPathValue("id", "nope")
	rec := serveAuthed(h.Patch, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}

func TestDeleteRemoves(t *testing.T) {
	store := &fakeStore{statuses: map[string]string{"f1": "nuevo"}}
	h := &Handler{Store: store}
	req := authedReq("DELETE", "/admin/feedback/f1", "")
	req.SetPathValue("id", "f1")
	rec := serveAuthed(h.Delete, req)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	if store.deleted[0] != "f1" {
		t.Fatalf("deleted = %v", store.deleted)
	}
}

func TestDeleteNotFound(t *testing.T) {
	h := &Handler{Store: &fakeStore{statuses: map[string]string{}}}
	req := authedReq("DELETE", "/admin/feedback/nope", "")
	req.SetPathValue("id", "nope")
	rec := serveAuthed(h.Delete, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}
