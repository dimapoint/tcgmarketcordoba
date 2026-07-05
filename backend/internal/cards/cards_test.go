package cards

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakeStore struct{ results []Printing }

func (f *fakeStore) Search(_ context.Context, q string) ([]Printing, error) {
	return f.results, nil
}

func TestSearchShortQueryReturnsEmptyArray(t *testing.T) {
	h := &Handler{Store: &fakeStore{results: []Printing{{CardName: "Jinx"}}}}
	rec := httptest.NewRecorder()
	h.Search(rec, httptest.NewRequest("GET", "/cards/search?q=j", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d", rec.Code)
	}
	if body := strings.TrimSpace(rec.Body.String()); body != "[]" {
		t.Fatalf("body = %q, want []", body)
	}
}

func TestSearchReturnsResults(t *testing.T) {
	h := &Handler{Store: &fakeStore{results: []Printing{{CardName: "Jinx"}}}}
	rec := httptest.NewRecorder()
	h.Search(rec, httptest.NewRequest("GET", "/cards/search?q=ji", nil))
	if !strings.Contains(rec.Body.String(), "Jinx") {
		t.Fatalf("body = %s", rec.Body)
	}
}

func TestSearchIncludesWantedCount(t *testing.T) {
	h := &Handler{Store: &fakeStore{results: []Printing{{CardName: "Jinx", WantedCount: 2}}}}
	rec := httptest.NewRecorder()
	h.Search(rec, httptest.NewRequest("GET", "/cards/search?q=ji", nil))
	if !strings.Contains(rec.Body.String(), `"wanted_count":2`) {
		t.Fatalf("body = %s, want wanted_count 2", rec.Body)
	}
}
