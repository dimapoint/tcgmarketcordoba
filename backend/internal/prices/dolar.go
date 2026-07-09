package prices

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

const DefaultDolarBaseURL = "https://dolarapi.com"

// DolarAPI trae la cotización del dólar blue (venta) de dolarapi.com,
// cacheada en memoria (default 1h). Con la caché vencida y la API caída
// sirve la cotización vieja antes que nada.
type DolarAPI struct {
	BaseURL string
	HTTP    *http.Client
	TTL     time.Duration    // default 1h
	Now     func() time.Time // inyectable en tests; default time.Now

	mu      sync.Mutex
	fetched time.Time
	rate    float64
}

func (c *DolarAPI) Rate(ctx context.Context) (float64, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	now := time.Now
	if c.Now != nil {
		now = c.Now
	}
	ttl := c.TTL
	if ttl == 0 {
		ttl = time.Hour
	}
	if c.rate != 0 && now().Sub(c.fetched) < ttl {
		return c.rate, nil
	}

	fresh, err := c.fetch(ctx)
	if err != nil {
		if c.rate != 0 {
			return c.rate, nil // stale antes que nada
		}
		return 0, err
	}
	c.rate, c.fetched = fresh, now()
	return c.rate, nil
}

func (c *DolarAPI) fetch(ctx context.Context) (float64, error) {
	base := c.BaseURL
	if base == "" {
		base = DefaultDolarBaseURL
	}
	httpc := c.HTTP
	if httpc == nil {
		httpc = &http.Client{Timeout: 15 * time.Second}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, base+"/v1/dolares/blue", nil)
	if err != nil {
		return 0, err
	}
	req.Header.Set("User-Agent", priceUserAgent)
	resp, err := httpc.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("HTTP %d de dolarapi", resp.StatusCode)
	}
	var body struct {
		Venta float64 `json:"venta"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return 0, err
	}
	if body.Venta <= 0 {
		return 0, fmt.Errorf("cotización inválida: %v", body.Venta)
	}
	return body.Venta, nil
}
