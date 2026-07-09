package prices

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakeStore struct {
	printing    PrintingInfo
	printingErr error
	stats       LocalStats
	statsErr    error
}

func (f *fakeStore) Printing(_ context.Context, id string) (PrintingInfo, error) {
	return f.printing, f.printingErr
}
func (f *fakeStore) LocalStats(_ context.Context, id string) (LocalStats, error) {
	return f.stats, f.statsErr
}

type fakeMarket struct {
	usd *float64
	err error
}

func (f *fakeMarket) Price(_ context.Context, tcgplayerID string, foil bool) (*float64, error) {
	return f.usd, f.err
}

type fakeRate struct {
	rate float64
	err  error
}

func (f *fakeRate) Rate(_ context.Context) (float64, error) { return f.rate, f.err }

func f64(v float64) *float64 { return &v }
func strp(s string) *string  { return &s }

func get(t *testing.T, h *Handler, id string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/card-printings/"+id+"/price-reference", nil)
	req.SetPathValue("id", id)
	rec := httptest.NewRecorder()
	h.PriceReference(rec, req)
	return rec
}

func decode(t *testing.T, rec *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("JSON inválido: %v (%s)", err, rec.Body.String())
	}
	return body
}

func TestPriceReferenceFullData(t *testing.T) {
	h := &Handler{
		Store: &fakeStore{
			printing: PrintingInfo{TCGPlayerID: strp("684492"), IsFoil: true},
			stats:    LocalStats{ActiveCount: 3, MinPrice: f64(10000)},
		},
		Market: &fakeMarket{usd: f64(15.26)},
		Rate:   &fakeRate{rate: 1510},
	}
	rec := get(t, h, "p1")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	body := decode(t, rec)
	if body["market_usd"] != 15.26 {
		t.Errorf("market_usd = %v", body["market_usd"])
	}
	// 15.26 * 1510 = 23042.6 → redondeado a $100 → 23000
	if body["market_ars"] != float64(23000) {
		t.Errorf("market_ars = %v", body["market_ars"])
	}
	if body["fx_rate"] != float64(1510) {
		t.Errorf("fx_rate = %v", body["fx_rate"])
	}
	if body["is_foil"] != true {
		t.Errorf("is_foil = %v", body["is_foil"])
	}
	if body["local_active_count"] != float64(3) || body["local_min_price"] != float64(10000) {
		t.Errorf("local = %v / %v", body["local_active_count"], body["local_min_price"])
	}
}

func TestPriceReferenceNotFound(t *testing.T) {
	h := &Handler{
		Store:  &fakeStore{printingErr: ErrNotFound},
		Market: &fakeMarket{},
		Rate:   &fakeRate{},
	}
	rec := get(t, h, "nope")
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d", rec.Code)
	}
	if body := decode(t, rec); body["error"] == "" {
		t.Errorf("falta mensaje de error: %v", body)
	}
}

func TestPriceReferenceWithoutTCGPlayerID(t *testing.T) {
	market := &fakeMarket{usd: f64(99)}
	h := &Handler{
		Store: &fakeStore{
			printing: PrintingInfo{TCGPlayerID: nil, IsFoil: false},
			stats:    LocalStats{ActiveCount: 1, MinPrice: f64(5000)},
		},
		Market: market,
		Rate:   &fakeRate{rate: 1510},
	}
	rec := get(t, h, "p1")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	body := decode(t, rec)
	if body["market_usd"] != nil || body["market_ars"] != nil {
		t.Errorf("sin tcgplayer_id debería no haber mercado: %v", body)
	}
	if body["local_active_count"] != float64(1) {
		t.Errorf("local_active_count = %v", body["local_active_count"])
	}
}

func TestPriceReferenceMarketSourceDegrades(t *testing.T) {
	h := &Handler{
		Store: &fakeStore{
			printing: PrintingInfo{TCGPlayerID: strp("1"), IsFoil: false},
			stats:    LocalStats{},
		},
		Market: &fakeMarket{err: errors.New("tcgcsv caído")},
		Rate:   &fakeRate{rate: 1510},
	}
	rec := get(t, h, "p1")
	if rec.Code != http.StatusOK {
		t.Fatalf("una fuente externa caída no debe romper el endpoint: %d", rec.Code)
	}
	body := decode(t, rec)
	if body["market_usd"] != nil || body["market_ars"] != nil {
		t.Errorf("mercado debería ser null: %v", body)
	}
}

func TestPriceReferenceRateDegrades(t *testing.T) {
	h := &Handler{
		Store: &fakeStore{
			printing: PrintingInfo{TCGPlayerID: strp("1"), IsFoil: false},
			stats:    LocalStats{},
		},
		Market: &fakeMarket{usd: f64(10)},
		Rate:   &fakeRate{err: errors.New("dolarapi caído")},
	}
	rec := get(t, h, "p1")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	body := decode(t, rec)
	if body["market_usd"] != float64(10) {
		t.Errorf("market_usd = %v, want 10", body["market_usd"])
	}
	if body["market_ars"] != nil || body["fx_rate"] != nil {
		t.Errorf("sin tipo de cambio no hay ARS: %v", body)
	}
}

func TestPriceReferenceStoreError(t *testing.T) {
	h := &Handler{
		Store:  &fakeStore{printingErr: errors.New("db caída")},
		Market: &fakeMarket{},
		Rate:   &fakeRate{},
	}
	rec := get(t, h, "p1")
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d", rec.Code)
	}
}
