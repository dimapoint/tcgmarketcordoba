package matches

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
	matches    []Match
	unseen     int
	seenCalled string
	err        error
}

func (f *fakeStore) ForBuyer(_ context.Context, buyerID string) ([]Match, error) {
	if f.err != nil {
		return nil, f.err
	}
	return f.matches, nil
}

func (f *fakeStore) UnseenCount(_ context.Context, buyerID string) (int, error) {
	if f.err != nil {
		return 0, f.err
	}
	return f.unseen, nil
}

func (f *fakeStore) MarkSeen(_ context.Context, buyerID string) error {
	f.seenCalled = buyerID
	return f.err
}

func authedReq(method, target string) *http.Request {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("buyer-1")
	r := httptest.NewRequest(method, target, nil)
	r.Header.Set("Authorization", "Bearer "+tok)
	return r
}

func serveAuthed(h http.HandlerFunc, r *http.Request) *httptest.ResponseRecorder {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	rec := httptest.NewRecorder()
	auth.Middleware(issuer)(h).ServeHTTP(rec, r)
	return rec
}

func TestListReturnsMatchesWithIsNew(t *testing.T) {
	h := &Handler{Store: &fakeStore{matches: []Match{
		{ListingID: "l1", CardName: "Jinx", Price: 3000, IsNew: true},
	}}}
	rec := serveAuthed(h.List, authedReq("GET", "/me/matches"))
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	var out []Match
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if len(out) != 1 || out[0].CardName != "Jinx" || !out[0].IsNew {
		t.Fatalf("unexpected body: %s", rec.Body)
	}
}

func TestListStoreError500(t *testing.T) {
	h := &Handler{Store: &fakeStore{err: errors.New("boom")}}
	rec := serveAuthed(h.List, authedReq("GET", "/me/matches"))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("code = %d, want 500", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "error interno") {
		t.Fatalf("body = %s", rec.Body)
	}
}

func TestUnseenCountReturnsJSONCount(t *testing.T) {
	h := &Handler{Store: &fakeStore{unseen: 4}}
	rec := serveAuthed(h.UnseenCount, authedReq("GET", "/me/matches/count"))
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	if strings.TrimSpace(rec.Body.String()) != `{"count":4}` {
		t.Fatalf("body = %s, want {\"count\":4}", rec.Body)
	}
}

func TestMarkSeenUsesJWTUserAndReturns204(t *testing.T) {
	store := &fakeStore{}
	h := &Handler{Store: store}
	rec := serveAuthed(h.MarkSeen, authedReq("POST", "/me/matches/seen"))
	if rec.Code != http.StatusNoContent {
		t.Fatalf("code = %d, want 204: %s", rec.Code, rec.Body)
	}
	if store.seenCalled != "buyer-1" {
		t.Fatalf("MarkSeen called with %q, want buyer-1 from JWT", store.seenCalled)
	}
}

func TestEndpointsRequireAuth(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	for name, fn := range map[string]http.HandlerFunc{
		"list": h.List, "count": h.UnseenCount, "seen": h.MarkSeen,
	} {
		rec := serveAuthed(fn, httptest.NewRequest("GET", "/me/matches", nil))
		if rec.Code != http.StatusUnauthorized {
			t.Errorf("%s: code = %d, want 401 sin token", name, rec.Code)
		}
	}
}
