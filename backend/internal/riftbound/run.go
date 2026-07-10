package riftbound

import (
	"context"
	"fmt"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

// SyncAll corre Sync con una transacción por set: si la conexión se corta a
// mitad de camino, lo commiteado queda y reintentar es barato (el sync es
// idempotente). Lo usan el CLI riftbound-sync y el endpoint admin.
func SyncAll(ctx context.Context, pool *pgxpool.Pool, content *Content) (Summary, error) {
	var total Summary
	for _, set := range content.Sets {
		sum, err := syncSet(ctx, pool, content, set)
		if err != nil {
			return total, fmt.Errorf("set %s: %w", set.ID, err)
		}
		total.Sets += sum.Sets
		total.Cards += sum.Cards
		total.NewCards += sum.NewCards
		total.Printings += sum.Printings
		log.Printf("set %s ok: %d cartas (%d nuevas), %d printings",
			set.ID, sum.Cards, sum.NewCards, sum.Printings)
	}
	return total, nil
}

func syncSet(ctx context.Context, pool *pgxpool.Pool, content *Content, set Set) (Summary, error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return Summary{}, err
	}
	defer tx.Rollback(ctx)

	one := &Content{
		Game:        content.Game,
		Version:     content.Version,
		LastUpdated: content.LastUpdated,
		Sets:        []Set{set},
	}
	sum, err := Sync(ctx, NewPgStore(tx), one)
	if err != nil {
		return sum, err
	}
	return sum, tx.Commit(ctx)
}
