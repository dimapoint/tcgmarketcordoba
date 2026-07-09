package riftbound

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"

	"context"
)

const rcKeywordsJSON = `{"total":3,"type":"keywords","values":["Accelerate","Quick-Draw","11"]}`

func rcCardJSON(riftboundID, name string, energy, might, power any, superType any, domains []string, plain string, flavour any, rarity string) string {
	doms := `"` + strings.Join(domains, `","`) + `"`
	if len(domains) == 0 {
		doms = ""
	}
	return fmt.Sprintf(`{
		"id":"abc","name":%q,"riftbound_id":%q,"tcgplayer_id":"1","collector_number":%d,
		"attributes":{"energy":%v,"might":%v,"power":%v},
		"classification":{"type":"Unit","supertype":%v,"rarity":%q,"domain":[%s]},
		"text":{"rich":"<p>x</p>","plain":%q,"flavour":%v},
		"set":{"set_id":"OGN","label":"Origins"},
		"media":{"image_url":"https://cdn.example/%s.png","artist":"Alguien","accessibility_text":"x"},
		"tags":["Zaun"],"orientation":"portrait",
		"metadata":{"clean_name":"x","alternate_art":false,"overnumbered":false,"signature":false}
	}`, name, riftboundID, 1, energy, might, power, superType, rarity, doms, plain, flavour, riftboundID)
}

// newRiftcodexServer arma un server con keywords, sets y páginas de cartas por set.
func newRiftcodexServer(t *testing.T, setsJSON string, cardPages map[string][]string, requests *[]string) *httptest.Server {
	t.Helper()
	mux := http.NewServeMux()
	mux.HandleFunc("/index/keywords", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, rcKeywordsJSON)
	})
	mux.HandleFunc("/sets", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, setsJSON)
	})
	mux.HandleFunc("/cards", func(w http.ResponseWriter, r *http.Request) {
		setID := r.URL.Query().Get("set_id")
		page := r.URL.Query().Get("page")
		if page == "" {
			page = "1"
		}
		pages := cardPages[setID]
		var idx int
		fmt.Sscanf(page, "%d", &idx)
		if idx < 1 || idx > len(pages) {
			http.Error(w, `{"detail":"page out of range"}`, http.StatusNotFound)
			return
		}
		fmt.Fprint(w, pages[idx-1])
	})
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if requests != nil {
			*requests = append(*requests, r.URL.RequestURI())
		}
		if ua := r.Header.Get("User-Agent"); !strings.HasPrefix(ua, "tcgmarketcordoba-sync/") {
			t.Errorf("User-Agent = %q", ua)
		}
		mux.ServeHTTP(w, r)
	}))
}

func rcPage(pages, total int, cards ...string) string {
	return fmt.Sprintf(`{"items":[%s],"total":%d,"page":1,"size":100,"pages":%d}`,
		strings.Join(cards, ","), total, pages)
}

func TestRiftcodexFetchContentMapsCards(t *testing.T) {
	setsJSON := `{"items":[{"id":"x","name":"Origins","set_id":"OGN","card_count":3,"tcgplayer_id":"1","cardmarket_id":null,"published_on":"2025-10-31T00:00:00"}],"total":1,"page":1,"size":50,"pages":1}`
	cardPages := map[string][]string{
		"ogn": {rcPage(1, 3,
			rcCardJSON("ogn-001-298", "Jinx, Demolitionist", 3, 4, 2, `"Champion"`,
				[]string{"Fury", "Mind"}, "[Accelerate] Boom.", `"Get excited!"`, "Epic"),
			rcCardJSON("ogn-060-298", "Vilemaw", 8, 8, "null", "null",
				[]string{"Calm"}, "[Ambush] scary", "null", "Rare"),
			rcCardJSON("ogn-060a-298", "Vilemaw (Alternate Art)", 8, 8, "null", "null",
				[]string{"Calm"}, "[Ambush] scary", "null", "Showcase"),
		)},
	}
	srv := newRiftcodexServer(t, setsJSON, cardPages, nil)
	defer srv.Close()

	client := &RiftcodexClient{BaseURL: srv.URL}
	content, err := client.FetchContent(context.Background())
	if err != nil {
		t.Fatalf("FetchContent: %v", err)
	}

	if len(content.Sets) != 1 {
		t.Fatalf("sets = %d, want 1", len(content.Sets))
	}
	set := content.Sets[0]
	if set.ID != "OGN" || set.Name != "Origins" || set.ReleaseDate != "2025-10-31" {
		t.Errorf("set = %+v", set)
	}
	if len(set.Cards) != 3 {
		t.Fatalf("cards = %d, want 3", len(set.Cards))
	}

	jinx := set.Cards[0]
	if jinx.ID != "OGN-001-298" || jinx.Number != "001" || jinx.Name != "Jinx, Demolitionist" {
		t.Errorf("jinx id/number/name = %+v", jinx)
	}
	if jinx.Type != "Champion" || jinx.Rarity != "Epic" || jinx.Faction != "Fury,Mind" {
		t.Errorf("jinx clasificación = %+v", jinx)
	}
	if jinx.Stats.Energy == nil || *jinx.Stats.Energy != 3 ||
		jinx.Stats.Might == nil || *jinx.Stats.Might != 4 ||
		jinx.Stats.Power == nil || *jinx.Stats.Power != 2 {
		t.Errorf("jinx stats = %+v", jinx.Stats)
	}
	if !reflect.DeepEqual(jinx.Keywords, []string{"Accelerate"}) {
		t.Errorf("jinx keywords = %v", jinx.Keywords)
	}
	if jinx.Description != "[Accelerate] Boom." || jinx.FlavorText != "Get excited!" {
		t.Errorf("jinx textos = %+v", jinx)
	}
	if !reflect.DeepEqual(jinx.Tags, []string{"Zaun"}) {
		t.Errorf("jinx tags = %v", jinx.Tags)
	}
	if jinx.Art.FullURL != "https://cdn.example/ogn-001-298.png" ||
		jinx.Art.Artist != "Alguien" || jinx.Art.ThumbnailURL != "" {
		t.Errorf("jinx art = %+v", jinx.Art)
	}
	if jinx.TCGPlayerID != "1" {
		t.Errorf("jinx tcgplayer_id = %q, want \"1\"", jinx.TCGPlayerID)
	}

	// sin supertype cae al type; flavour null queda vacío
	vilemaw := set.Cards[1]
	if vilemaw.Type != "Unit" || vilemaw.Stats.Power != nil || vilemaw.FlavorText != "" {
		t.Errorf("vilemaw = %+v", vilemaw)
	}
	// "Ambush" no está en el índice de keywords del fixture → se descarta
	if len(vilemaw.Keywords) != 0 {
		t.Errorf("vilemaw keywords = %v", vilemaw.Keywords)
	}

	// alt-art: sufijo del nombre afuera, número con letra
	alt := set.Cards[2]
	if alt.Name != "Vilemaw" || alt.Number != "060a" || alt.ID != "OGN-060A-298" {
		t.Errorf("alt = %+v", alt)
	}
	if alt.Rarity != "Showcase" {
		t.Errorf("alt rarity = %q", alt.Rarity)
	}
}

func TestRiftcodexVariantAndTokenNumbers(t *testing.T) {
	setsJSON := `{"items":[{"id":"x","name":"Promos","set_id":"OPP","card_count":7,"tcgplayer_id":"1","cardmarket_id":null,"published_on":null}],"total":1,"page":1,"size":50,"pages":1}`
	cardPages := map[string][]string{
		"opp": {rcPage(1, 7,
			// mismo número, distinto denominador: dos cartas distintas
			rcCardJSON("opp-001-024", "Annie - Fiery", 1, 1, "null", "null", []string{"Fury"}, "a", "null", "Promo"),
			rcCardJSON("opp-001-298", "Blazing Scorcher", 2, 2, "null", "null", []string{"Fury"}, "b", "null", "Promo"),
			// variante Metal: comparte riftbound_id exacto con la base
			rcCardJSON("opp-017-024", "Annie - Dark Child", 3, 3, "null", "null", []string{"Fury"}, "c", "null", "Promo"),
			rcCardJSON("opp-017-024", "Annie - Dark Child (Metal)", 3, 3, "null", "null", []string{"Fury"}, "c", "null", "Promo"),
			// Metal sin conflicto de número: igual lleva sufijo m
			rcCardJSON("opp-183-221", "Lucian - Purifier (Metal)", 4, 4, "null", "null", []string{"Order"}, "d", "null", "Promo"),
			rcCardJSON("opp-183-298", "Stacked Deck", 5, 5, "null", "null", []string{"Order"}, "e", "null", "Promo"),
			// token con id de 2 segmentos
			rcCardJSON("opp-t03", "Gold Token", "null", "null", "null", "null", []string{}, "f", "null", "Token"),
		)},
	}
	srv := newRiftcodexServer(t, setsJSON, cardPages, nil)
	defer srv.Close()

	client := &RiftcodexClient{BaseURL: srv.URL}
	content, err := client.FetchContent(context.Background())
	if err != nil {
		t.Fatalf("FetchContent: %v", err)
	}
	cards := content.Sets[0].Cards
	if len(cards) != 7 {
		t.Fatalf("cards = %d, want 7", len(cards))
	}

	got := map[string]bool{}
	for _, c := range cards {
		got[c.ID+"|"+c.Name+"|"+c.Number] = true
	}
	want := []string{
		"OPP-001-024|Annie - Fiery|001-024",
		"OPP-001-298|Blazing Scorcher|001-298",
		"OPP-017-024|Annie - Dark Child|017",  // la base queda con el número limpio
		"OPP-017-024|Annie - Dark Child|017m", // la Metal comparte carta, printing propio
		"OPP-183-221|Lucian - Purifier|183m",  // Metal siempre con sufijo m
		"OPP-183-298|Stacked Deck|183",
		"OPP-T03|Gold Token|t03",
	}
	for _, key := range want {
		if !got[key] {
			t.Errorf("falta %s (got=%v)", key, got)
		}
	}
	// la Metal de Annie comparte nombre con la base y lleva número 017m
	metalSeen := false
	for _, c := range cards {
		if c.Number == "017m" {
			metalSeen = true
			if c.Name != "Annie - Dark Child" {
				t.Errorf("metal name = %q, want base sin sufijo", c.Name)
			}
		}
		if strings.Contains(c.Name, "(Metal)") {
			t.Errorf("quedó nombre con sufijo Metal: %q", c.Name)
		}
	}
	if !metalSeen {
		t.Error("no apareció el printing 017m")
	}
	// los números resultantes no colisionan
	seen := map[string]bool{}
	for _, c := range cards {
		if seen[c.Number] {
			t.Errorf("número duplicado tras desambiguar: %q", c.Number)
		}
		seen[c.Number] = true
	}
}

func TestRiftcodexPagination(t *testing.T) {
	setsJSON := `{"items":[{"id":"x","name":"Unleashed","set_id":"UNL","card_count":2,"tcgplayer_id":"1","cardmarket_id":null,"published_on":"2026-05-08T00:00:00"}],"total":1,"page":1,"size":50,"pages":1}`
	cardPages := map[string][]string{
		"unl": {
			rcPage(2, 2, rcCardJSON("unl-001-219", "Uno", 1, 1, "null", "null", []string{"Fury"}, "a", "null", "Common")),
			rcPage(2, 2, rcCardJSON("unl-002-219", "Dos", 2, 2, "null", "null", []string{"Fury"}, "b", "null", "Common")),
		},
	}
	var requests []string
	srv := newRiftcodexServer(t, setsJSON, cardPages, &requests)
	defer srv.Close()

	client := &RiftcodexClient{BaseURL: srv.URL}
	content, err := client.FetchContent(context.Background())
	if err != nil {
		t.Fatalf("FetchContent: %v", err)
	}

	cards := content.Sets[0].Cards
	if len(cards) != 2 || cards[0].Name != "Uno" || cards[1].Name != "Dos" {
		t.Fatalf("cards = %+v", cards)
	}

	var cardReqs []string
	for _, r := range requests {
		if strings.HasPrefix(r, "/cards") {
			cardReqs = append(cardReqs, r)
		}
	}
	if len(cardReqs) != 2 {
		t.Fatalf("card requests = %v", cardReqs)
	}
	for i, r := range cardReqs {
		if !strings.Contains(r, "set_id=unl") {
			t.Errorf("request sin set_id en minúscula: %s", r)
		}
		if !strings.Contains(r, fmt.Sprintf("page=%d", i+1)) || !strings.Contains(r, "size=100") {
			t.Errorf("request %d con paginación inesperada: %s", i+1, r)
		}
	}
}

func TestRiftcodexKeywordIndexFiltersJunk(t *testing.T) {
	setsJSON := `{"items":[{"id":"x","name":"Origins","set_id":"OGN","card_count":1,"tcgplayer_id":"1","cardmarket_id":null,"published_on":null}],"total":1,"page":1,"size":50,"pages":1}`
	cardPages := map[string][]string{
		"ogn": {rcPage(1, 1, rcCardJSON("ogn-001-298", "Uno", 1, 1, "null", "null",
			[]string{"Fury"}, "[11] [Accelerate] [Quick-Draw] [NotAKeyword] [Accelerate]", "null", "Common"))},
	}
	srv := newRiftcodexServer(t, setsJSON, cardPages, nil)
	defer srv.Close()

	client := &RiftcodexClient{BaseURL: srv.URL}
	content, err := client.FetchContent(context.Background())
	if err != nil {
		t.Fatalf("FetchContent: %v", err)
	}
	card := content.Sets[0].Cards[0]
	// "11" (basura del índice) y "NotAKeyword" afuera; sin duplicados
	if !reflect.DeepEqual(card.Keywords, []string{"Accelerate", "Quick-Draw"}) {
		t.Errorf("keywords = %v", card.Keywords)
	}
	// published_on null → sin fecha
	if content.Sets[0].ReleaseDate != "" {
		t.Errorf("release date = %q", content.Sets[0].ReleaseDate)
	}
}

func TestRiftcodexEmptySetStillEmitted(t *testing.T) {
	setsJSON := `{"items":[{"id":"x","name":"Vendetta","set_id":"VEN","card_count":0,"tcgplayer_id":null,"cardmarket_id":null,"published_on":"2026-07-31T00:00:00"}],"total":1,"page":1,"size":50,"pages":1}`
	srv := newRiftcodexServer(t, setsJSON, map[string][]string{}, nil)
	defer srv.Close()

	client := &RiftcodexClient{BaseURL: srv.URL}
	content, err := client.FetchContent(context.Background())
	if err != nil {
		t.Fatalf("FetchContent: %v", err)
	}
	if len(content.Sets) != 1 || content.Sets[0].ID != "VEN" || len(content.Sets[0].Cards) != 0 {
		t.Errorf("sets = %+v", content.Sets)
	}
}

func TestRiftcodexRetriesOn429And5xx(t *testing.T) {
	attempts := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		switch attempts {
		case 1:
			w.Header().Set("Retry-After", "0")
			w.WriteHeader(http.StatusTooManyRequests)
		case 2:
			w.WriteHeader(http.StatusInternalServerError)
		default:
			fmt.Fprint(w, rcKeywordsJSON)
			// después del índice devolvemos sets vacíos para terminar rápido
			if attempts > 3 {
				fmt.Fprint(w, "")
			}
		}
	}))
	defer srv.Close()

	// solo verificamos que el primer GET (índice de keywords) reintente;
	// /sets responderá el JSON de keywords que no tiene items → 0 sets.
	client := &RiftcodexClient{BaseURL: srv.URL}
	content, err := client.FetchContent(context.Background())
	if err != nil {
		t.Fatalf("FetchContent: %v", err)
	}
	if attempts < 3 {
		t.Errorf("attempts = %d, want >= 3", attempts)
	}
	if len(content.Sets) != 0 {
		t.Errorf("sets = %+v", content.Sets)
	}
}

func TestRiftcodexGivesUpAfterMaxRetries(t *testing.T) {
	attempts := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		w.Header().Set("Retry-After", "0")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer srv.Close()

	client := &RiftcodexClient{BaseURL: srv.URL}
	if _, err := client.FetchContent(context.Background()); err == nil {
		t.Fatal("esperaba error tras agotar reintentos")
	}
	if attempts != maxAttempts {
		t.Errorf("attempts = %d, want %d", attempts, maxAttempts)
	}
}
