package riftbound

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
	"unicode"
)

// RiftcodexClient baja el catálogo desde la API pública de riftcodex.com
// (sin auth) y lo mapea al mismo árbol Content/Set/Card del cliente de Riot,
// así Sync y PgStore se reutilizan sin cambios.
type RiftcodexClient struct {
	BaseURL string
	HTTP    *http.Client
}

const DefaultRiftcodexBaseURL = "https://api.riftcodex.com"

const riftcodexUserAgent = "tcgmarketcordoba-sync/1.0"

const altArtSuffix = " (Alternate Art)"

const metalSuffix = " (Metal)"

// DTOs del wire de riftcodex.
type rcSet struct {
	Name        string  `json:"name"`
	SetID       string  `json:"set_id"`
	CardCount   int     `json:"card_count"`
	PublishedOn *string `json:"published_on"`
}

type rcCard struct {
	Name            string `json:"name"`
	RiftboundID     string `json:"riftbound_id"`
	TCGPlayerID     string `json:"tcgplayer_id"`
	CollectorNumber int64  `json:"collector_number"`
	Attributes      struct {
		Energy *int64 `json:"energy"`
		Might  *int64 `json:"might"`
		Power  *int64 `json:"power"`
	} `json:"attributes"`
	Classification struct {
		Type      string   `json:"type"`
		Supertype *string  `json:"supertype"`
		Rarity    string   `json:"rarity"`
		Domain    []string `json:"domain"`
	} `json:"classification"`
	Text struct {
		Plain   string  `json:"plain"`
		Flavour *string `json:"flavour"`
	} `json:"text"`
	Media struct {
		ImageURL string `json:"image_url"`
		Artist   string `json:"artist"`
	} `json:"media"`
	Tags []string `json:"tags"`
}

type rcSetsPage struct {
	Items []rcSet `json:"items"`
	Pages int     `json:"pages"`
}

type rcCardsPage struct {
	Items []rcCard `json:"items"`
	Pages int      `json:"pages"`
}

type rcKeywordIndex struct {
	Values []string `json:"values"`
}

func (c *RiftcodexClient) FetchContent(ctx context.Context) (*Content, error) {
	base := c.BaseURL
	if base == "" {
		base = DefaultRiftcodexBaseURL
	}
	httpc := c.HTTP
	if httpc == nil {
		httpc = &http.Client{Timeout: 60 * time.Second}
	}

	keywords, err := c.fetchKeywordIndex(ctx, httpc, base)
	if err != nil {
		return nil, fmt.Errorf("índice de keywords: %w", err)
	}

	var setsPage rcSetsPage
	if err := getJSON(ctx, httpc, base+"/sets?size=100", &setsPage); err != nil {
		return nil, fmt.Errorf("sets: %w", err)
	}

	content := &Content{
		Game:        "Riftbound",
		Version:     "riftcodex",
		LastUpdated: time.Now().UTC().Format(time.RFC3339),
	}
	for _, rs := range setsPage.Items {
		set := Set{
			ID:          rs.SetID,
			Name:        rs.Name,
			ReleaseDate: datePart(rs.PublishedOn),
		}
		if rs.CardCount > 0 {
			cards, err := c.fetchSetCards(ctx, httpc, base, rs.SetID, keywords)
			if err != nil {
				return nil, fmt.Errorf("cartas del set %s: %w", rs.SetID, err)
			}
			set.Cards = cards
		}
		content.Sets = append(content.Sets, set)
	}
	return content, nil
}

// fetchKeywordIndex arma el mapa lower→canónico de keywords válidos,
// descartando valores basura del índice (los que no arrancan con letra).
func (c *RiftcodexClient) fetchKeywordIndex(ctx context.Context, httpc *http.Client, base string) (map[string]string, error) {
	var idx rcKeywordIndex
	if err := getJSON(ctx, httpc, base+"/index/keywords", &idx); err != nil {
		return nil, err
	}
	keywords := make(map[string]string, len(idx.Values))
	for _, kw := range idx.Values {
		runes := []rune(kw)
		if len(runes) == 0 || !unicode.IsLetter(runes[0]) {
			continue
		}
		keywords[strings.ToLower(kw)] = kw
	}
	return keywords, nil
}

func (c *RiftcodexClient) fetchSetCards(ctx context.Context, httpc *http.Client, base, setID string, keywords map[string]string) ([]Card, error) {
	var cards []Card
	var lastSegs []string // segmento final del riftbound_id, paralelo a cards
	for page := 1; ; page++ {
		u := fmt.Sprintf("%s/cards?set_id=%s&sort=collector_number&page=%d&size=100",
			base, url.QueryEscape(strings.ToLower(setID)), page)
		var p rcCardsPage
		if err := getJSON(ctx, httpc, u, &p); err != nil {
			return nil, err
		}
		for _, rc := range p.Items {
			cards = append(cards, mapRiftcodexCard(rc, keywords))
			lastSegs = append(lastSegs, lastSegment(rc.RiftboundID))
		}
		if page >= p.Pages {
			break
		}
	}
	disambiguateNumbers(cards, lastSegs)
	return cards, nil
}

// disambiguateNumbers resuelve los promos (OPP) que repiten número impreso
// con distinto denominador ("opp-001-024" vs "opp-001-298" son cartas
// distintas): a los números repetidos les agrega el denominador. Corre
// después del sufijo m de las Metal, que resuelve los pares con id idéntico.
func disambiguateNumbers(cards []Card, lastSegs []string) {
	counts := map[string]int{}
	for _, c := range cards {
		counts[c.Number]++
	}
	for i := range cards {
		if counts[cards[i].Number] > 1 && lastSegs[i] != "" {
			cards[i].Number += "-" + lastSegs[i]
		}
	}
}

func mapRiftcodexCard(rc rcCard, keywords map[string]string) Card {
	cardType := rc.Classification.Type
	if rc.Classification.Supertype != nil && *rc.Classification.Supertype != "" {
		cardType = *rc.Classification.Supertype
	}
	name := strings.TrimSuffix(rc.Name, altArtSuffix)
	number := printedNumber(rc.RiftboundID)
	// Las variantes Metal comparten riftbound_id con la carta base: misma
	// fila de cards (como los alt-arts) y printing propio con sufijo m.
	if strings.HasSuffix(name, metalSuffix) {
		name = strings.TrimSuffix(name, metalSuffix)
		number += "m"
	}
	return Card{
		ID:              strings.ToUpper(rc.RiftboundID),
		TCGPlayerID:     rc.TCGPlayerID,
		CollectorNumber: rc.CollectorNumber,
		Number:          number,
		Name:            name,
		Description:     rc.Text.Plain,
		Type:            cardType,
		Rarity:          rc.Classification.Rarity,
		Faction:         strings.Join(rc.Classification.Domain, ","),
		Stats: Stats{
			Energy: rc.Attributes.Energy,
			Might:  rc.Attributes.Might,
			Power:  rc.Attributes.Power,
		},
		Keywords:   extractKeywords(rc.Text.Plain, keywords),
		FlavorText: derefOrEmpty(rc.Text.Flavour),
		Tags:       rc.Tags,
		Art: Art{
			FullURL: rc.Media.ImageURL,
			Artist:  rc.Media.Artist,
		},
	}
}

// printedNumber saca el número impreso del riftbound_id: "unl-060a-219" →
// "060a". Los tokens vienen sin denominador ("sfd-t03" → "t03"). Con un
// formato inesperado devuelve "" y Sync cae al collector number.
func printedNumber(riftboundID string) string {
	parts := strings.Split(riftboundID, "-")
	switch {
	case len(parts) >= 3:
		return strings.Join(parts[1:len(parts)-1], "-")
	case len(parts) == 2:
		return parts[1]
	default:
		return ""
	}
}

// lastSegment devuelve el denominador del riftbound_id ("opp-001-024" →
// "024"), o "" si el id no lo trae (tokens).
func lastSegment(riftboundID string) string {
	parts := strings.Split(riftboundID, "-")
	if len(parts) < 3 {
		return ""
	}
	return parts[len(parts)-1]
}

var bracketedToken = regexp.MustCompile(`\[([^\[\]]+)\]`)

// extractKeywords junta los tokens [Keyword] del texto plano que existan en
// el índice, con el casing canónico del índice y sin duplicados.
func extractKeywords(plain string, keywords map[string]string) []string {
	var out []string
	seen := map[string]bool{}
	for _, m := range bracketedToken.FindAllStringSubmatch(plain, -1) {
		canonical, ok := keywords[strings.ToLower(m[1])]
		if !ok || seen[canonical] {
			continue
		}
		seen[canonical] = true
		out = append(out, canonical)
	}
	return out
}

// getJSON hace un GET con el mismo esquema de reintentos que el cliente de
// Riot: 3 intentos ante 429/5xx respetando Retry-After.
func getJSON(ctx context.Context, httpc *http.Client, url string, dst any) error {
	var lastErr error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
		if err != nil {
			return err
		}
		req.Header.Set("User-Agent", riftcodexUserAgent)

		resp, err := httpc.Do(req)
		if err != nil {
			return err
		}

		switch {
		case resp.StatusCode == http.StatusOK:
			err := json.NewDecoder(resp.Body).Decode(dst)
			resp.Body.Close()
			if err != nil {
				return fmt.Errorf("decodificando %s: %w", url, err)
			}
			return nil
		case resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500:
			lastErr = fmt.Errorf("HTTP %d de riftcodex (%s)", resp.StatusCode, url)
			wait := retryAfter(resp)
			resp.Body.Close()
			if attempt < maxAttempts {
				select {
				case <-time.After(wait):
				case <-ctx.Done():
					return ctx.Err()
				}
			}
		default:
			resp.Body.Close()
			return fmt.Errorf("HTTP %d inesperado de riftcodex (%s)", resp.StatusCode, url)
		}
	}
	return fmt.Errorf("agotados %d intentos: %w", maxAttempts, lastErr)
}

func datePart(ts *string) string {
	if ts == nil {
		return ""
	}
	if t, err := time.Parse("2006-01-02T15:04:05", *ts); err == nil {
		return t.Format("2006-01-02")
	}
	if len(*ts) >= 10 {
		return (*ts)[:10]
	}
	return ""
}

func derefOrEmpty(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
