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

	total, err := riftbound.SyncAll(ctx, pool, content)
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("sync ok: %d sets, %d cartas (%d nuevas), %d printings",
		total.Sets, total.Cards, total.NewCards, total.Printings)
}
