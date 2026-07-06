package riftbound

import (
	"context"
	"fmt"
	"reflect"
	"testing"
)

// fakeStore graba las llamadas y devuelve ids deterministas.
type fakeStore struct {
	games     []string
	sets      []string
	types     []string
	rarities  []string
	domains   []string
	keywords  []string
	cards     []CardRow
	printings []PrintingRow
	cardDoms  map[string][]string
	cardKws   map[string][]string
}

func newFakeStore() *fakeStore {
	return &fakeStore{cardDoms: map[string][]string{}, cardKws: map[string][]string{}}
}

func (f *fakeStore) EnsureGame(_ context.Context, slug, name string) (string, error) {
	f.games = append(f.games, slug)
	return "game:" + slug, nil
}
func (f *fakeStore) UpsertSet(_ context.Context, gameID, code, name string, releaseDate *string) (string, error) {
	date := "<nil>"
	if releaseDate != nil {
		date = *releaseDate
	}
	f.sets = append(f.sets, fmt.Sprintf("%s|%s|%s|%s", gameID, code, name, date))
	return "set:" + code, nil
}
func (f *fakeStore) EnsureCardType(_ context.Context, gameID, name string) (string, error) {
	f.types = append(f.types, name)
	return "type:" + name, nil
}
func (f *fakeStore) EnsureRarity(_ context.Context, gameID, name string) (string, error) {
	f.rarities = append(f.rarities, name)
	return "rarity:" + name, nil
}
func (f *fakeStore) EnsureDomain(_ context.Context, gameID, name string) (string, error) {
	f.domains = append(f.domains, name)
	return "domain:" + name, nil
}
func (f *fakeStore) EnsureKeyword(_ context.Context, gameID, name string) (string, error) {
	f.keywords = append(f.keywords, name)
	return "keyword:" + name, nil
}
func (f *fakeStore) UpsertCard(_ context.Context, c CardRow) (string, bool, error) {
	f.cards = append(f.cards, c)
	return "card:" + c.Name, true, nil
}
func (f *fakeStore) ReplaceCardDomains(_ context.Context, cardID string, domainIDs []string) error {
	f.cardDoms[cardID] = domainIDs
	return nil
}
func (f *fakeStore) ReplaceCardKeywords(_ context.Context, cardID string, keywordIDs []string) error {
	f.cardKws[cardID] = keywordIDs
	return nil
}
func (f *fakeStore) UpsertPrinting(_ context.Context, p PrintingRow) (bool, error) {
	f.printings = append(f.printings, p)
	return true, nil
}

func i64(v int64) *int64 { return &v }

func testContent() *Content {
	return &Content{
		Game: "Riftbound",
		Sets: []Set{{
			ID:          "OGN",
			Name:        "Origins",
			ReleaseDate: "2025-10-31",
			Cards: []Card{
				{
					ID: "OGN-030", CollectorNumber: 30, Set: "OGN",
					Name: "Jinx, Demolitionist", Description: "Boom desc.",
					Type: "CHAMPION", Rarity: "EPIC", Faction: "FURY,CHAOS",
					Stats:    Stats{Energy: i64(3), Might: i64(4), Power: i64(2)},
					Keywords: []string{"ACCELERATE"},
					Art: Art{
						ThumbnailURL: "https://cdn.example/030-thumb.png",
						FullURL:      "https://cdn.example/030.png",
						Artist:       "Alguien",
					},
					FlavorText: "Boom.", Tags: []string{"ZAUN"},
				},
				// alt-art de la misma carta: mismo nombre, otro número y rareza.
				// Number viene explícito (estilo riftcodex "320a"); las demás
				// cartas lo dejan vacío y cae al %03d del collector number.
				{
					ID: "OGN-320", CollectorNumber: 320, Number: "320a", Set: "OGN",
					Name: "Jinx, Demolitionist", Description: "Boom desc.",
					Type: "CHAMPION", Rarity: "ALTERNATE ART", Faction: "FURY,CHAOS",
					Stats:    Stats{Energy: i64(3), Might: i64(4), Power: i64(2)},
					Keywords: []string{"ACCELERATE"},
					Art:      Art{FullURL: "https://cdn.example/320.png"},
				},
				// Legend sin stats
				{
					ID: "OGN-251", CollectorNumber: 251, Set: "OGN",
					Name: "Loose Cannon", Type: "LEGEND", Rarity: "RARE",
					Faction: "CHAOS",
				},
				// Common: única rareza (junto a Uncommon) con versión normal
				{
					ID: "OGN-012", CollectorNumber: 12, Set: "OGN",
					Name: "Poro Herder", Type: "UNIT", Rarity: "COMMON",
					Faction: "BODY",
				},
			},
		}, {
			// Proving Grounds: producto fijo, sin foils ni siquiera en rares
			ID:   "OGS",
			Name: "Origins: Proving Grounds",
			Cards: []Card{
				{
					ID: "OGS-004", CollectorNumber: 4, Set: "OGS",
					Name: "Master Yi - Meditative", Type: "LEGEND", Rarity: "RARE",
					Faction: "MIND",
				},
			},
		}},
	}
}

func TestSyncMapsAndUpserts(t *testing.T) {
	store := newFakeStore()
	sum, err := Sync(context.Background(), store, testContent())
	if err != nil {
		t.Fatalf("Sync: %v", err)
	}

	if !reflect.DeepEqual(store.games, []string{"riftbound"}) {
		t.Errorf("games = %v", store.games)
	}
	wantSets := []string{
		"game:riftbound|OGN|Origins|2025-10-31",
		"game:riftbound|OGS|Origins: Proving Grounds|<nil>",
	}
	if !reflect.DeepEqual(store.sets, wantSets) {
		t.Errorf("sets = %v", store.sets)
	}

	// referencias normalizadas a Title Case
	wantTypes := map[string]bool{"Champion": true, "Legend": true, "Unit": true}
	for _, ty := range store.types {
		if !wantTypes[ty] {
			t.Errorf("card type sin normalizar: %q", ty)
		}
	}
	wantRarities := map[string]bool{"Epic": true, "Alternate Art": true, "Rare": true, "Common": true}
	for _, r := range store.rarities {
		if !wantRarities[r] {
			t.Errorf("rarity sin normalizar: %q", r)
		}
	}
	wantDomains := map[string]bool{"Fury": true, "Chaos": true, "Body": true, "Mind": true}
	for _, d := range store.domains {
		if !wantDomains[d] {
			t.Errorf("domain sin normalizar: %q", d)
		}
	}
	for _, k := range store.keywords {
		if k != "Accelerate" {
			t.Errorf("keyword sin normalizar: %q", k)
		}
	}

	// 4 cartas únicas (el alt-art comparte fila de cards)
	if len(store.cards) != 4 {
		t.Fatalf("cards = %d, want 4 (%+v)", len(store.cards), store.cards)
	}
	jinx := store.cards[0]
	if jinx.Name != "Jinx, Demolitionist" || jinx.CardTypeID != "type:Champion" {
		t.Errorf("jinx = %+v", jinx)
	}
	if jinx.EnergyCost == nil || *jinx.EnergyCost != 3 || jinx.Might == nil || *jinx.Might != 4 {
		t.Errorf("jinx stats = %+v", jinx)
	}
	if jinx.PowerCost == nil || *jinx.PowerCost != "2 Fury" {
		t.Errorf("jinx power_cost = %v, want \"2 Fury\"", jinx.PowerCost)
	}
	if jinx.Description == nil || *jinx.Description != "Boom desc." ||
		jinx.FlavorText == nil || *jinx.FlavorText != "Boom." ||
		!reflect.DeepEqual(jinx.Tags, []string{"ZAUN"}) {
		t.Errorf("jinx textos = %+v", jinx)
	}

	legend := store.cards[1]
	if legend.Name != "Loose Cannon" || legend.CardTypeID != "type:Legend" {
		t.Errorf("legend = %+v", legend)
	}
	if legend.EnergyCost != nil || legend.Might != nil || legend.PowerCost != nil {
		t.Errorf("legend sin stats deberia tener nils: %+v", legend)
	}
	if legend.FlavorText != nil {
		t.Errorf("legend flavor deberia ser nil: %+v", legend.FlavorText)
	}

	// dominios y keywords vinculados por carta
	if !reflect.DeepEqual(store.cardDoms["card:Jinx, Demolitionist"], []string{"domain:Fury", "domain:Chaos"}) {
		t.Errorf("cardDoms jinx = %v", store.cardDoms)
	}
	if !reflect.DeepEqual(store.cardKws["card:Jinx, Demolitionist"], []string{"keyword:Accelerate"}) {
		t.Errorf("cardKws jinx = %v", store.cardKws)
	}

	// Epic/Alternate Art/Rare existen solo foil; Common en normal y foil;
	// OGS (Proving Grounds) es producto fijo solo normal:
	// epic + altart + rare + common×2 + ogs = 6 printings
	if len(store.printings) != 6 {
		t.Fatalf("printings = %d, want 6 (%+v)", len(store.printings), store.printings)
	}
	epic := store.printings[0]
	if epic.CardNumber != "030" || !epic.IsFoil || epic.SetID != "set:OGN" ||
		epic.RarityID != "rarity:Epic" || epic.RiotCardID != "OGN-030" {
		t.Errorf("epic = %+v", epic)
	}
	if epic.ImageURL == nil || *epic.ImageURL != "https://cdn.example/030.png" ||
		epic.ThumbnailURL == nil || *epic.ThumbnailURL != "https://cdn.example/030-thumb.png" ||
		epic.Artist == nil || *epic.Artist != "Alguien" {
		t.Errorf("epic art = %+v", epic)
	}
	altArt := store.printings[1]
	if altArt.CardNumber != "320a" || !altArt.IsFoil ||
		altArt.RarityID != "rarity:Alternate Art" ||
		altArt.CardID != "card:Jinx, Demolitionist" {
		t.Errorf("altArt = %+v", altArt)
	}
	if altArt.ThumbnailURL != nil || altArt.Artist != nil {
		t.Errorf("altArt sin thumb/artist deberia tener nils: %+v", altArt)
	}
	rare := store.printings[2]
	if rare.CardNumber != "251" || !rare.IsFoil || rare.RarityID != "rarity:Rare" {
		t.Errorf("rare = %+v", rare)
	}
	common, commonFoil := store.printings[3], store.printings[4]
	if common.CardNumber != "012" || common.IsFoil || common.RarityID != "rarity:Common" {
		t.Errorf("common = %+v", common)
	}
	if commonFoil.CardNumber != "012" || !commonFoil.IsFoil {
		t.Errorf("commonFoil = %+v", commonFoil)
	}
	ogs := store.printings[5]
	if ogs.SetID != "set:OGS" || ogs.CardNumber != "004" || ogs.IsFoil ||
		ogs.RarityID != "rarity:Rare" {
		t.Errorf("ogs = %+v", ogs)
	}

	if sum.Cards != 4 || sum.Printings != 6 || sum.Sets != 2 {
		t.Errorf("summary = %+v", sum)
	}
}

func TestTitleCase(t *testing.T) {
	cases := map[string]string{
		"CHAMPION":      "Champion",
		"ALTERNATE ART": "Alternate Art",
		"Fury":          "Fury",
		"epic":          "Epic",
		"QUICK-DRAW":    "Quick-Draw",
		"Quick-Draw":    "Quick-Draw",
	}
	for in, want := range cases {
		if got := titleCase(in); got != want {
			t.Errorf("titleCase(%q) = %q, want %q", in, got, want)
		}
	}
}
