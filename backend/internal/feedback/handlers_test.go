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
	created  []Feedback
	all      []Feedback
	err      error
	lastUser string
}

func (f *fakeStore) Create(_ context.Context, userID, category, message string) error {
	if f.err != nil {
		return f.err
	}
	f.lastUser = userID
	f.created = append(f.created, Feedback{UserID: userID, Category: category, Message: message})
	return nil
}

func (f *fakeStore) List(_ context.Context) ([]Feedback, error) {
	if f.err != nil {
		return nil, f.err
	}
	return f.all, nil
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
		"create": h.Create, "list": h.List,
	} {
		rec := serveAuthed(fn, httptest.NewRequest("GET", "/feedback", nil))
		if rec.Code != http.StatusUnauthorized {
			t.Errorf("%s: code = %d, want 401 sin token", name, rec.Code)
		}
	}
}
