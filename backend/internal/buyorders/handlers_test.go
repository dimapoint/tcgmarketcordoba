package buyorders

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"tcgmarketcordoba/internal/auth"
)

type fakeStore struct {
	items       map[string]BuyOrder
	profileCity *string
	created     *CreateParams
	createErr   error
}

func (f *fakeStore) Active(_ context.Context, query string) ([]BuyOrder, error) {
	out := []BuyOrder{}
	for _, o := range f.items {
		if o.Status == "active" {
			out = append(out, o)
		}
	}
	return out, nil
}

func (f *fakeStore) ByID(_ context.Context, id string) (BuyOrder, error) {
	o, ok := f.items[id]
	if !ok {
		return BuyOrder{}, ErrNotFound
	}
	return o, nil
}

func (f *fakeStore) Mine(_ context.Context, buyerID, status string) ([]BuyOrder, error) {
	out := []BuyOrder{}
	for _, o := range f.items {
		if o.BuyerID == buyerID && o.Status == status {
			out = append(out, o)
		}
	}
	return out, nil
}

func (f *fakeStore) Create(_ context.Context, p CreateParams) (BuyOrder, error) {
	if f.createErr != nil {
		return BuyOrder{}, f.createErr
	}
	if p.CityID == nil && f.profileCity == nil {
		return BuyOrder{}, ErrNoCity
	}
	f.created = &p
	return BuyOrder{ID: "new-1", BuyerID: p.BuyerID, Status: "active"}, nil
}

func (f *fakeStore) UpdateStatus(_ context.Context, id, buyerID, status string) error {
	o, ok := f.items[id]
	if !ok || o.BuyerID != buyerID {
		return ErrNotFound
	}
	o.Status = status
	f.items[id] = o
	return nil
}

func authedReq(method, target, body string) *http.Request {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("buyer-1")
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

func TestListReturnsActiveBuyOrders(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]BuyOrder{
		"b1": {ID: "b1", CardName: "Jinx", Status: "active"},
	}}}
	rec := httptest.NewRecorder()
	h.List(rec, httptest.NewRequest("GET", "/buy-orders", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d", rec.Code)
	}
	var out []BuyOrder
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if len(out) != 1 || out[0].CardName != "Jinx" {
		t.Fatalf("unexpected body: %s", rec.Body)
	}
}

func TestGetUnknownBuyOrder404(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]BuyOrder{}}}
	req := httptest.NewRequest("GET", "/buy-orders/nope", nil)
	req.SetPathValue("id", "nope")
	rec := httptest.NewRecorder()
	h.Get(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}

func TestCreateBuyOrderWithoutCity422(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]BuyOrder{}}}
	rec := serveAuthed(h.Create, authedReq("POST", "/buy-orders",
		`{"card_printing_id":"cp1","max_price":100}`))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422: %s", rec.Code, rec.Body)
	}
}

func TestCreateBuyOrderDuplicateActiveCard409(t *testing.T) {
	city := "city-1"
	store := &fakeStore{
		items:       map[string]BuyOrder{},
		profileCity: &city,
		createErr:   ErrDuplicateActiveBuyOrder,
	}
	h := &Handler{Store: store}
	rec := serveAuthed(h.Create, authedReq("POST", "/buy-orders",
		`{"card_printing_id":"cp1","max_price":100}`))
	if rec.Code != http.StatusConflict {
		t.Fatalf("code = %d, want 409: %s", rec.Code, rec.Body)
	}
	if !strings.Contains(rec.Body.String(), "Ya tenés una búsqueda activa de esta carta.") {
		t.Fatalf("body = %s", rec.Body)
	}
}

func TestCreateBuyOrderMissingMaxPrice422(t *testing.T) {
	city := "city-1"
	h := &Handler{Store: &fakeStore{items: map[string]BuyOrder{}, profileCity: &city}}
	rec := serveAuthed(h.Create, authedReq("POST", "/buy-orders",
		`{"card_printing_id":"cp1"}`))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422: %s", rec.Code, rec.Body)
	}
}

func TestCreateBuyOrderHappyPathNoCondition(t *testing.T) {
	city := "city-1"
	store := &fakeStore{items: map[string]BuyOrder{}, profileCity: &city}
	h := &Handler{Store: store}
	rec := serveAuthed(h.Create, authedReq("POST", "/buy-orders",
		`{"card_printing_id":"cp1","max_price":100.5}`))
	if rec.Code != http.StatusCreated {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	if store.created == nil || store.created.BuyerID != "buyer-1" {
		t.Fatal("Create not called with buyer from JWT")
	}
	if store.created.MinCondition != nil {
		t.Fatalf("min condition should be optional, got %v", store.created.MinCondition)
	}
	if store.created.Quantity != 1 {
		t.Fatalf("quantity should default to 1, got %d", store.created.Quantity)
	}
}

func TestCreateBuyOrderInvalidCondition422(t *testing.T) {
	city := "city-1"
	h := &Handler{Store: &fakeStore{items: map[string]BuyOrder{}, profileCity: &city}}
	rec := serveAuthed(h.Create, authedReq("POST", "/buy-orders",
		`{"card_printing_id":"cp1","max_price":100,"min_condition":"XX"}`))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422: %s", rec.Code, rec.Body)
	}
}

func TestPatchStatusNotOwner404(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]BuyOrder{
		"b1": {ID: "b1", BuyerID: "otro", Status: "active"},
	}}}
	req := authedReq("PATCH", "/buy-orders/b1", `{"status":"fulfilled"}`)
	req.SetPathValue("id", "b1")
	rec := serveAuthed(h.Patch, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("code = %d, want 404", rec.Code)
	}
}

func TestMyBuyOrdersIncludesMatchingCount(t *testing.T) {
	h := &Handler{Store: &fakeStore{items: map[string]BuyOrder{
		"b1": {ID: "b1", BuyerID: "buyer-1", Status: "active", MatchingListingsCount: 3},
	}}}
	req := authedReq("GET", "/me/buy-orders?status=active", "")
	rec := serveAuthed(h.MyBuyOrders, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	if !strings.Contains(rec.Body.String(), `"matching_listings_count":3`) {
		t.Fatalf("body = %s, want matching_listings_count 3", rec.Body)
	}
}
