package admin

import (
	"context"
	"errors"
	"sync"
	"time"

	"tcgmarketcordoba/internal/riftbound"
)

var ErrSyncRunning = errors.New("sync en curso")

type SyncState struct {
	Status     string             `json:"status"` // idle | running | ok | error
	StartedAt  *time.Time         `json:"started_at,omitempty"`
	FinishedAt *time.Time         `json:"finished_at,omitempty"`
	Summary    *riftbound.Summary `json:"summary,omitempty"`
	Error      string             `json:"error,omitempty"`
}

type Syncer interface {
	Start() error
	Status() SyncState
}

// SyncRunner corre el sync de cartas en una goroutine, de a uno por vez.
// El estado vive en memoria: con una sola máquina alcanza, y si el proceso
// se reinicia a mitad de corrida no se pierde nada (el sync es idempotente
// con commit por set; se vuelve a disparar y listo).
type SyncRunner struct {
	mu    sync.Mutex
	state SyncState

	Fetch func(ctx context.Context) (*riftbound.Content, error)
	Run   func(ctx context.Context, content *riftbound.Content) (riftbound.Summary, error)
}

func (r *SyncRunner) Start() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.state.Status == "running" {
		return ErrSyncRunning
	}
	now := time.Now()
	r.state = SyncState{Status: "running", StartedAt: &now}

	// context.Background(), no el del request: la respuesta 202 vuelve
	// enseguida y la corrida sigue sola.
	go r.run(context.Background())
	return nil
}

func (r *SyncRunner) run(ctx context.Context) {
	summary, err := func() (riftbound.Summary, error) {
		content, err := r.Fetch(ctx)
		if err != nil {
			return riftbound.Summary{}, err
		}
		return r.Run(ctx, content)
	}()

	r.mu.Lock()
	defer r.mu.Unlock()
	now := time.Now()
	r.state.FinishedAt = &now
	if err != nil {
		r.state.Status = "error"
		r.state.Error = err.Error()
		return
	}
	r.state.Status = "ok"
	r.state.Summary = &summary
}

func (r *SyncRunner) Status() SyncState {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.state.Status == "" {
		return SyncState{Status: "idle"}
	}
	return r.state
}
