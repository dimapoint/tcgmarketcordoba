package admin

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"testing"
	"time"

	"tcgmarketcordoba/internal/riftbound"
)

func newTestRunner(block chan struct{}, runErr error) *SyncRunner {
	return &SyncRunner{
		Fetch: func(ctx context.Context) (*riftbound.Content, error) {
			return &riftbound.Content{}, nil
		},
		Run: func(ctx context.Context, c *riftbound.Content) (riftbound.Summary, error) {
			if block != nil {
				<-block
			}
			return riftbound.Summary{Sets: 8, Cards: 964}, runErr
		},
	}
}

func waitStatus(t *testing.T, r *SyncRunner, want string) SyncState {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if st := r.Status(); st.Status == want {
			return st
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("status nunca llegó a %q (actual %q)", want, r.Status().Status)
	return SyncState{}
}

func TestSyncRunnerSingleFlight(t *testing.T) {
	block := make(chan struct{})
	r := newTestRunner(block, nil)

	if err := r.Start(); err != nil {
		t.Fatal(err)
	}
	if err := r.Start(); !errors.Is(err, ErrSyncRunning) {
		t.Fatalf("segundo Start = %v, want ErrSyncRunning", err)
	}
	if st := r.Status(); st.Status != "running" || st.StartedAt == nil {
		t.Fatalf("estado durante corrida = %+v", st)
	}

	close(block)
	st := waitStatus(t, r, "ok")
	if st.Summary == nil || st.Summary.Cards != 964 || st.FinishedAt == nil {
		t.Fatalf("estado final = %+v", st)
	}

	// terminado, se puede volver a arrancar
	if err := r.Start(); err != nil {
		t.Fatalf("re-Start tras ok = %v", err)
	}
	waitStatus(t, r, "ok")
}

func TestSyncRunnerReportsError(t *testing.T) {
	r := newTestRunner(nil, errors.New("se cayó riftcodex"))
	if err := r.Start(); err != nil {
		t.Fatal(err)
	}
	st := waitStatus(t, r, "error")
	if st.Error != "se cayó riftcodex" {
		t.Fatalf("error = %q", st.Error)
	}
}

func TestSyncEndpoints(t *testing.T) {
	block := make(chan struct{})
	r := newTestRunner(block, nil)
	h, store, _, _ := testModHandler()
	h.Sync = r

	requireAdmin := func(fn http.HandlerFunc) http.Handler {
		return protect(store, fn)
	}
	mux := http.NewServeMux()
	mux.Handle("POST /admin/sync-cards", requireAdmin(h.StartSync))
	mux.Handle("GET /admin/sync-cards", requireAdmin(h.SyncStatus))

	rec := adminDo(t, mux,"POST", "/admin/sync-cards", "")
	if rec.Code != http.StatusAccepted {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}

	rec2 := adminDo(t, mux,"POST", "/admin/sync-cards", "")
	if rec2.Code != http.StatusConflict {
		t.Fatalf("segundo POST code = %d, want 409", rec2.Code)
	}

	rec3 := adminDo(t, mux,"GET", "/admin/sync-cards", "")
	if rec3.Code != http.StatusOK {
		t.Fatalf("GET code = %d", rec3.Code)
	}
	var st SyncState
	if err := json.Unmarshal(rec3.Body.Bytes(), &st); err != nil {
		t.Fatal(err)
	}
	if st.Status != "running" {
		t.Fatalf("status = %q, want running", st.Status)
	}
	close(block)
	waitStatus(t, r, "ok")
}
