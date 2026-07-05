// riftbound-sync baja el catálogo completo de cartas y lo upsertea en la
// base. Re-ejecutable: correrlo de nuevo actualiza y agrega, nunca borra.
//
// Fuentes: riftcodex.com (default, sin key) o la API oficial de Riot
// (requiere RIOT_API_KEY en backend/.env).
//
//	cd backend && go run ./cmd/riftbound-sync
//	cd backend && go run ./cmd/riftbound-sync -source riot
package main

import (
	"context"
	"flag"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"

	"tcgmarketcordoba/internal/config"
	"tcgmarketcordoba/internal/db"
	"tcgmarketcordoba/internal/riftbound"
)

type fetcher interface {
	FetchContent(ctx context.Context) (*riftbound.Content, error)
}

func main() {
	source := flag.String("source", "riftcodex", "fuente del catálogo: riftcodex|riot")
	flag.Parse()

	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}

	var client fetcher
	switch *source {
	case "riftcodex":
		client = &riftbound.RiftcodexClient{}
	case "riot":
		if cfg.RiotAPIKey == "" {
			log.Fatal("RIOT_API_KEY is required for -source riot (backend/.env)")
		}
		client = &riftbound.Client{APIKey: cfg.RiotAPIKey}
	default:
		log.Fatalf("fuente desconocida %q (usar riftcodex|riot)", *source)
	}

	ctx := context.Background()

	content, err := client.FetchContent(ctx)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("contenido %s v%s (actualizado %s): %d sets",
		content.Game, content.Version, content.LastUpdated, len(content.Sets))

	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	// Una transacción por set: si la conexión se corta a mitad de camino,
	// lo commiteado queda y reintentar es barato (el sync es idempotente).
	var total riftbound.Summary
	for _, set := range content.Sets {
		sum, err := syncSet(ctx, pool, content, set)
		if err != nil {
			log.Fatalf("set %s: %v", set.ID, err)
		}
		total.Sets += sum.Sets
		total.Cards += sum.Cards
		total.NewCards += sum.NewCards
		total.Printings += sum.Printings
		log.Printf("set %s ok: %d cartas (%d nuevas), %d printings",
			set.ID, sum.Cards, sum.NewCards, sum.Printings)
	}

	log.Printf("sync ok: %d sets, %d cartas (%d nuevas), %d printings",
		total.Sets, total.Cards, total.NewCards, total.Printings)
}

func syncSet(ctx context.Context, pool *pgxpool.Pool, content *riftbound.Content, set riftbound.Set) (riftbound.Summary, error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return riftbound.Summary{}, err
	}
	defer tx.Rollback(ctx)

	one := &riftbound.Content{
		Game:        content.Game,
		Version:     content.Version,
		LastUpdated: content.LastUpdated,
		Sets:        []riftbound.Set{set},
	}
	sum, err := riftbound.Sync(ctx, riftbound.NewPgStore(tx), one)
	if err != nil {
		return sum, err
	}
	return sum, tx.Commit(ctx)
}
