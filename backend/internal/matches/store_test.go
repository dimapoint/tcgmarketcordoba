package matches

import (
	"strings"
	"testing"
)

// Las publicaciones propias no son novedad: si vendés la carta que vos mismo
// buscás, no tiene sentido notificarte.
func TestMatchQueriesExcludeOwnListings(t *testing.T) {
	for name, q := range map[string]string{
		"forBuyer": forBuyerQuery, "unseenCount": unseenCountQuery,
	} {
		if !strings.Contains(q, "l.seller_id <> bo.buyer_id") {
			t.Errorf("%s no excluye las publicaciones del propio comprador", name)
		}
	}
}

// El conteo del badge sólo cuenta lo aparecido después de la última visita;
// la lista trae todo el match actual y marca is_new con el mismo criterio.
func TestUnseenCountFiltersBySeenMark(t *testing.T) {
	if !strings.Contains(unseenCountQuery, "l.created_at > me.matches_seen_at") {
		t.Error("unseenCountQuery no filtra por matches_seen_at")
	}
	if !strings.Contains(forBuyerQuery, "l.created_at > me.matches_seen_at AS is_new") {
		t.Error("forBuyerQuery no calcula is_new contra matches_seen_at")
	}
}

// Mismos criterios de match que la subquery matching_count de buyorders:
// precio dentro del máximo y condición al menos tan buena como la mínima.
func TestMatchQueriesShareBuyOrderCriteria(t *testing.T) {
	for _, frag := range []string{
		"l.price <= bo.max_price",
		"bo.min_condition IS NULL OR l.condition <= bo.min_condition",
	} {
		if !strings.Contains(forBuyerQuery, frag) {
			t.Errorf("forBuyerQuery no contiene %q", frag)
		}
		if !strings.Contains(unseenCountQuery, frag) {
			t.Errorf("unseenCountQuery no contiene %q", frag)
		}
	}
}
