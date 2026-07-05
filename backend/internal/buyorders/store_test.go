package buyorders

import (
	"strings"
	"testing"
)

// Regresión: la subquery de matching_count tiene que quedar en la lista del
// SELECT, no concatenada después de los JOINs (eso la convierte en un cross
// join que referencia bo sin LATERAL y Postgres la rechaza con 42P01).
func TestMineQueryPutsMatchingCountInSelectList(t *testing.T) {
	from := strings.Index(mineQuery, "FROM buy_orders")
	if from == -1 {
		t.Fatal("mineQuery no contiene FROM buy_orders")
	}
	count := strings.Index(mineQuery, "AS matching_count")
	if count == -1 {
		t.Fatal("mineQuery no contiene AS matching_count")
	}
	if count > from {
		t.Errorf("matching_count (pos %d) tiene que estar antes del FROM (pos %d): quedó en el FROM en vez de la lista del SELECT", count, from)
	}
}
