package auth

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestMiddlewareRejectsMissingToken(t *testing.T) {
	mw := Middleware(TokenIssuer{Secret: []byte("s"), TTL: time.Minute})
	rec := httptest.NewRecorder()
	mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("handler should not run")
	})).ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("code = %d, want 401", rec.Code)
	}
}

func TestMiddlewarePassesUserID(t *testing.T) {
	issuer := TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("user-9")
	var got string
	req := httptest.NewRequest("GET", "/", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	Middleware(issuer)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got = UserID(r.Context())
	})).ServeHTTP(httptest.NewRecorder(), req)
	if got != "user-9" {
		t.Fatalf("UserID = %q, want user-9", got)
	}
}
