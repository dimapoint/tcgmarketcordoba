package riftbound

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

const sampleContent = `{
	"game": "Riftbound",
	"version": "1.2.3",
	"lastUpdated": "2026-07-01T00:00:00Z",
	"sets": [
		{
			"id": "OGN",
			"name": "Origins",
			"cards": [
				{
					"id": "OGN-030",
					"collectorNumber": 30,
					"set": "OGN",
					"name": "Jinx, Demolitionist",
					"description": "When I attack, deal 1 damage.",
					"type": "CHAMPION",
					"rarity": "EPIC",
					"faction": "CHAOS",
					"stats": {"energy": 3, "might": 4, "cost": 0, "power": 2},
					"keywords": ["ACCELERATE"],
					"art": {
						"thumbnailURL": "https://cdn.example/ogn-030-thumb.png",
						"fullURL": "https://cdn.example/ogn-030.png",
						"artist": "Alguien"
					},
					"flavorText": "Boom.",
					"tags": ["ZAUN"]
				}
			]
		}
	]
}`

func TestFetchContentParsesResponse(t *testing.T) {
	var gotToken, gotLocale, gotPath string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotToken = r.Header.Get("X-Riot-Token")
		gotLocale = r.URL.Query().Get("locale")
		gotPath = r.URL.Path
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(sampleContent))
	}))
	defer srv.Close()

	c := &Client{BaseURL: srv.URL, APIKey: "test-key"}
	content, err := c.FetchContent(context.Background())
	if err != nil {
		t.Fatalf("FetchContent: %v", err)
	}

	if gotToken != "test-key" {
		t.Errorf("X-Riot-Token = %q, want test-key", gotToken)
	}
	if gotLocale != "en" {
		t.Errorf("locale = %q, want en", gotLocale)
	}
	if gotPath != "/riftbound/content/v1/contents" {
		t.Errorf("path = %q", gotPath)
	}
	if len(content.Sets) != 1 || content.Sets[0].ID != "OGN" || content.Sets[0].Name != "Origins" {
		t.Fatalf("sets = %+v", content.Sets)
	}
	card := content.Sets[0].Cards[0]
	if card.Name != "Jinx, Demolitionist" || card.CollectorNumber != 30 ||
		card.Rarity != "EPIC" || card.Faction != "CHAOS" || card.Type != "CHAMPION" {
		t.Errorf("card = %+v", card)
	}
	if card.Stats.Energy == nil || *card.Stats.Energy != 3 ||
		card.Stats.Might == nil || *card.Stats.Might != 4 ||
		card.Stats.Power == nil || *card.Stats.Power != 2 {
		t.Errorf("stats = %+v", card.Stats)
	}
	if card.Art.FullURL != "https://cdn.example/ogn-030.png" || card.Art.Artist != "Alguien" {
		t.Errorf("art = %+v", card.Art)
	}
	if len(card.Keywords) != 1 || card.Keywords[0] != "ACCELERATE" {
		t.Errorf("keywords = %v", card.Keywords)
	}
	if card.FlavorText != "Boom." || len(card.Tags) != 1 || card.Tags[0] != "ZAUN" {
		t.Errorf("flavor/tags = %q %v", card.FlavorText, card.Tags)
	}
}

func TestFetchContentForbiddenReturnsClearError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer srv.Close()

	c := &Client{BaseURL: srv.URL, APIKey: "expired"}
	_, err := c.FetchContent(context.Background())
	if err == nil {
		t.Fatal("want error on 403")
	}
	if !strings.Contains(err.Error(), "key") {
		t.Errorf("error should mention the key: %v", err)
	}
}

func TestFetchContentRetriesOn429And5xx(t *testing.T) {
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
			w.Write([]byte(sampleContent))
		}
	}))
	defer srv.Close()

	c := &Client{BaseURL: srv.URL, APIKey: "test-key"}
	content, err := c.FetchContent(context.Background())
	if err != nil {
		t.Fatalf("FetchContent after retries: %v", err)
	}
	if attempts != 3 {
		t.Errorf("attempts = %d, want 3", attempts)
	}
	if len(content.Sets) != 1 {
		t.Errorf("sets = %+v", content.Sets)
	}
}

func TestFetchContentGivesUpAfterMaxRetries(t *testing.T) {
	attempts := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		w.Header().Set("Retry-After", "0")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer srv.Close()

	c := &Client{BaseURL: srv.URL, APIKey: "test-key"}
	_, err := c.FetchContent(context.Background())
	if err == nil {
		t.Fatal("want error after exhausting retries")
	}
	if attempts != 3 {
		t.Errorf("attempts = %d, want 3", attempts)
	}
}
