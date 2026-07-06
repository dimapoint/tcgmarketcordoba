package riftbound

import (
	"context"
	"fmt"
	"strings"
)

// Store abstrae los upserts a la base; la implementación pgx vive en store.go.
type Store interface {
	EnsureGame(ctx context.Context, slug, name string) (string, error)
	UpsertSet(ctx context.Context, gameID, code, name string, releaseDate *string) (string, error)
	EnsureCardType(ctx context.Context, gameID, name string) (string, error)
	EnsureRarity(ctx context.Context, gameID, name string) (string, error)
	EnsureDomain(ctx context.Context, gameID, name string) (string, error)
	EnsureKeyword(ctx context.Context, gameID, name string) (string, error)
	UpsertCard(ctx context.Context, c CardRow) (id string, created bool, err error)
	ReplaceCardDomains(ctx context.Context, cardID string, domainIDs []string) error
	ReplaceCardKeywords(ctx context.Context, cardID string, keywordIDs []string) error
	UpsertPrinting(ctx context.Context, p PrintingRow) (created bool, err error)
}

type CardRow struct {
	CardTypeID  string
	Name        string
	EnergyCost  *int64
	PowerCost   *string
	Might       *int64
	Description *string
	FlavorText  *string
	Tags        []string
}

type PrintingRow struct {
	CardID       string
	SetID        string
	CardNumber   string
	IsFoil       bool
	RarityID     string
	RiotCardID   string
	ImageURL     *string
	ThumbnailURL *string
	Artist       *string
}

type Summary struct {
	Sets      int
	Cards     int
	Printings int
	NewCards  int
}

// memoStore cachea los Ensure* de referencia (tipos, rarezas, dominios,
// keywords): son ~40 valores distintos consultados miles de veces y cada
// round-trip al pooler cuesta ~90ms.
type memoStore struct {
	Store
	types, rarities, domains, keywords map[string]string
}

func newMemoStore(s Store) *memoStore {
	return &memoStore{
		Store: s,
		types: map[string]string{}, rarities: map[string]string{},
		domains: map[string]string{}, keywords: map[string]string{},
	}
}

func (m *memoStore) ensure(ctx context.Context, cache map[string]string, gameID, name string,
	fn func(context.Context, string, string) (string, error)) (string, error) {
	if id, ok := cache[name]; ok {
		return id, nil
	}
	id, err := fn(ctx, gameID, name)
	if err == nil {
		cache[name] = id
	}
	return id, err
}

func (m *memoStore) EnsureCardType(ctx context.Context, gameID, name string) (string, error) {
	return m.ensure(ctx, m.types, gameID, name, m.Store.EnsureCardType)
}
func (m *memoStore) EnsureRarity(ctx context.Context, gameID, name string) (string, error) {
	return m.ensure(ctx, m.rarities, gameID, name, m.Store.EnsureRarity)
}
func (m *memoStore) EnsureDomain(ctx context.Context, gameID, name string) (string, error) {
	return m.ensure(ctx, m.domains, gameID, name, m.Store.EnsureDomain)
}
func (m *memoStore) EnsureKeyword(ctx context.Context, gameID, name string) (string, error) {
	return m.ensure(ctx, m.keywords, gameID, name, m.Store.EnsureKeyword)
}

// Sync mapea el contenido de la API de Riot y lo upsertea vía store.
// No borra nada: los listings referencian printings existentes.
func Sync(ctx context.Context, store Store, content *Content) (Summary, error) {
	var sum Summary
	store = newMemoStore(store)

	gameID, err := store.EnsureGame(ctx, "riftbound", "Riftbound")
	if err != nil {
		return sum, err
	}

	// cache nombre normalizado → id de cards, para agrupar alt-arts
	cardIDs := map[string]string{}

	for _, set := range content.Sets {
		setID, err := store.UpsertSet(ctx, gameID, set.ID, set.Name, nilIfEmpty(set.ReleaseDate))
		if err != nil {
			return sum, fmt.Errorf("set %s: %w", set.ID, err)
		}
		sum.Sets++

		for _, card := range set.Cards {
			cardID, ok := cardIDs[card.Name]
			if !ok {
				cardID, err = syncCard(ctx, store, gameID, card, &sum)
				if err != nil {
					return sum, fmt.Errorf("carta %s (%s): %w", card.Name, card.ID, err)
				}
				cardIDs[card.Name] = cardID
				sum.Cards++
			}

			rarity := titleCase(card.Rarity)
			rarityID, err := store.EnsureRarity(ctx, gameID, rarity)
			if err != nil {
				return sum, err
			}
			for _, isFoil := range finishes(set.ID, rarity) {
				p := PrintingRow{
					CardID:       cardID,
					SetID:        setID,
					CardNumber:   cardNumber(card),
					IsFoil:       isFoil,
					RarityID:     rarityID,
					RiotCardID:   card.ID,
					ImageURL:     nilIfEmpty(card.Art.FullURL),
					ThumbnailURL: nilIfEmpty(card.Art.ThumbnailURL),
					Artist:       nilIfEmpty(card.Art.Artist),
				}
				if _, err := store.UpsertPrinting(ctx, p); err != nil {
					return sum, fmt.Errorf("printing %s foil=%v: %w", card.ID, isFoil, err)
				}
				sum.Printings++
			}
		}
	}
	return sum, nil
}

func syncCard(ctx context.Context, store Store, gameID string, card Card, sum *Summary) (string, error) {
	typeID, err := store.EnsureCardType(ctx, gameID, titleCase(card.Type))
	if err != nil {
		return "", err
	}

	domains := splitFactions(card.Faction)
	domainIDs := make([]string, 0, len(domains))
	for _, d := range domains {
		id, err := store.EnsureDomain(ctx, gameID, d)
		if err != nil {
			return "", err
		}
		domainIDs = append(domainIDs, id)
	}

	keywordIDs := make([]string, 0, len(card.Keywords))
	for _, k := range card.Keywords {
		id, err := store.EnsureKeyword(ctx, gameID, titleCase(k))
		if err != nil {
			return "", err
		}
		keywordIDs = append(keywordIDs, id)
	}

	row := CardRow{
		CardTypeID:  typeID,
		Name:        card.Name,
		EnergyCost:  card.Stats.Energy,
		PowerCost:   powerCost(card.Stats.Power, domains),
		Might:       card.Stats.Might,
		Description: nilIfEmpty(card.Description),
		FlavorText:  nilIfEmpty(card.FlavorText),
		Tags:        card.Tags,
	}
	cardID, created, err := store.UpsertCard(ctx, row)
	if err != nil {
		return "", err
	}
	if created {
		sum.NewCards++
	}
	if err := store.ReplaceCardDomains(ctx, cardID, domainIDs); err != nil {
		return "", err
	}
	if err := store.ReplaceCardKeywords(ctx, cardID, keywordIDs); err != nil {
		return "", err
	}
	return cardID, nil
}

// finishes devuelve qué versiones (is_foil) existen físicamente de un
// printing. En sobres "Every Rare and Epic will always be foil" (Riot):
// solo Common y Uncommon tienen versión normal; Showcase/Alternate Art,
// promos (OPP/PR/JDG) y Metal salen únicamente foil — confirmado contra los
// precios de TCGplayer (la variante Normal no tiene mercado). Proving
// Grounds (OGS) es el caso inverso: producto fijo sin foils.
func finishes(setCode, rarity string) []bool {
	if strings.EqualFold(setCode, "OGS") {
		return []bool{false}
	}
	switch rarity {
	case "Common", "Uncommon":
		return []bool{false, true}
	}
	return []bool{true}
}

// cardNumber prefiere el número impreso explícito (riftcodex, admite sufijos
// como "060a"); sin él cae al collector number zero-padded (Riot).
func cardNumber(card Card) string {
	if card.Number != "" {
		return card.Number
	}
	return fmt.Sprintf("%03d", card.CollectorNumber)
}

// powerCost arma el formato existente del seed ("2 Fury") con el primer dominio.
func powerCost(power *int64, domains []string) *string {
	if power == nil || *power == 0 || len(domains) == 0 {
		return nil
	}
	s := fmt.Sprintf("%d %s", *power, domains[0])
	return &s
}

func splitFactions(faction string) []string {
	var out []string
	for _, part := range strings.Split(faction, ",") {
		if p := strings.TrimSpace(part); p != "" {
			out = append(out, titleCase(p))
		}
	}
	return out
}

// titleCase normaliza los valores del API (vienen en mayúsculas) al formato
// del seed existente: "ALTERNATE ART" → "Alternate Art". Capitaliza también
// tras guiones ("QUICK-DRAW" → "Quick-Draw") y es idempotente sobre valores
// ya en Title Case (riftcodex).
func titleCase(s string) string {
	words := strings.Fields(strings.ToLower(s))
	for i, w := range words {
		parts := strings.Split(w, "-")
		for j, p := range parts {
			if p != "" {
				parts[j] = strings.ToUpper(p[:1]) + p[1:]
			}
		}
		words[i] = strings.Join(parts, "-")
	}
	return strings.Join(words, " ")
}

func nilIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
