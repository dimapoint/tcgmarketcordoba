package httpx

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestErrorWritesJSONShape(t *testing.T) {
	rec := httptest.NewRecorder()
	Error(rec, http.StatusNotFound, "no existe")
	if rec.Code != 404 {
		t.Fatalf("code = %d", rec.Code)
	}
	if got := rec.Body.String(); got != "{\"error\":\"no existe\"}\n" {
		t.Fatalf("body = %q", got)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Fatalf("content-type = %q", ct)
	}
}

func TestCORSHandlesPreflight(t *testing.T) {
	h := CORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTeapot)
	}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodOptions, "/x", nil))
	if rec.Code != http.StatusNoContent {
		t.Fatalf("preflight code = %d, want 204", rec.Code)
	}
	rec2 := httptest.NewRecorder()
	h.ServeHTTP(rec2, httptest.NewRequest(http.MethodGet, "/x", nil))
	if rec2.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Fatal("missing CORS header on normal request")
	}
}
