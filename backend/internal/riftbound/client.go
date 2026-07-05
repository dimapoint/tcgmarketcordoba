// Package riftbound sincroniza el catálogo de cartas desde la API
// pública de Riot (riftbound-content-v1) hacia la base de datos.
package riftbound

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"
)

const DefaultBaseURL = "https://americas.api.riotgames.com"

const maxAttempts = 3

type Content struct {
	Game        string `json:"game"`
	Version     string `json:"version"`
	LastUpdated string `json:"lastUpdated"`
	Sets        []Set  `json:"sets"`
}

type Set struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Cards []Card `json:"cards"`
	// ReleaseDate (YYYY-MM-DD) no viene en la API de Riot; lo llena riftcodex.
	ReleaseDate string `json:"-"`
}

type Card struct {
	ID              string   `json:"id"`
	CollectorNumber int64    `json:"collectorNumber"`
	// Number es el número impreso como string ("060a" en alt-arts). La API de
	// Riot no lo trae; si queda vacío, Sync usa %03d del CollectorNumber.
	Number string `json:"-"`
	Set             string   `json:"set"`
	Name            string   `json:"name"`
	Description     string   `json:"description"`
	Type            string   `json:"type"`
	Rarity          string   `json:"rarity"`
	Faction         string   `json:"faction"`
	Stats           Stats    `json:"stats"`
	Keywords        []string `json:"keywords"`
	Art             Art      `json:"art"`
	FlavorText      string   `json:"flavorText"`
	Tags            []string `json:"tags"`
}

// Stats usa punteros: los tipos sin stats (Legend, Battlefield, Rune)
// no traen los campos y eso debe distinguirse de un 0 real.
type Stats struct {
	Energy *int64 `json:"energy"`
	Might  *int64 `json:"might"`
	Cost   *int64 `json:"cost"`
	Power  *int64 `json:"power"`
}

type Art struct {
	ThumbnailURL string `json:"thumbnailURL"`
	FullURL      string `json:"fullURL"`
	Artist       string `json:"artist"`
}

type Client struct {
	BaseURL string
	APIKey  string
	HTTP    *http.Client
}

func (c *Client) FetchContent(ctx context.Context) (*Content, error) {
	base := c.BaseURL
	if base == "" {
		base = DefaultBaseURL
	}
	httpc := c.HTTP
	if httpc == nil {
		httpc = &http.Client{Timeout: 60 * time.Second}
	}
	url := base + "/riftbound/content/v1/contents?locale=en"

	var lastErr error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("X-Riot-Token", c.APIKey)

		resp, err := httpc.Do(req)
		if err != nil {
			return nil, err
		}

		switch {
		case resp.StatusCode == http.StatusOK:
			defer resp.Body.Close()
			var content Content
			if err := json.NewDecoder(resp.Body).Decode(&content); err != nil {
				return nil, fmt.Errorf("decodificando respuesta: %w", err)
			}
			return &content, nil
		case resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden:
			resp.Body.Close()
			return nil, fmt.Errorf("la API de Riot rechazó la key (HTTP %d): regenerala en developer.riotgames.com", resp.StatusCode)
		case resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500:
			lastErr = fmt.Errorf("HTTP %d de la API de Riot", resp.StatusCode)
			wait := retryAfter(resp)
			resp.Body.Close()
			if attempt < maxAttempts {
				select {
				case <-time.After(wait):
				case <-ctx.Done():
					return nil, ctx.Err()
				}
			}
		default:
			resp.Body.Close()
			return nil, fmt.Errorf("HTTP %d inesperado de la API de Riot", resp.StatusCode)
		}
	}
	return nil, fmt.Errorf("agotados %d intentos: %w", maxAttempts, lastErr)
}

func retryAfter(resp *http.Response) time.Duration {
	if s := resp.Header.Get("Retry-After"); s != "" {
		if secs, err := strconv.Atoi(s); err == nil {
			return time.Duration(secs) * time.Second
		}
	}
	return 2 * time.Second
}
