package prices

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"sync"
	"time"
)

const DefaultTCGCsvBaseURL = "https://tcgcsv.com"

// tcgcsv responde 401 al User-Agent default de Go: hace falta uno propio.
const priceUserAgent = "tcgmarketcordoba/1.0"

// riftboundCategoryID es la categoría de Riftbound en TCGplayer.
const riftboundCategoryID = 89

// TCGCsv sirve market prices de TCGplayer desde los dumps diarios de
// tcgcsv.com. Baja los precios de todos los grupos (sets) de Riftbound de
// una vez y los cachea en memoria; los dumps se regeneran a diario, así
// que un TTL de 24h alcanza. Con la caché vencida y tcgcsv caído sirve
// los datos viejos antes que nada.
type TCGCsv struct {
	BaseURL string
	HTTP    *http.Client
	TTL     time.Duration    // default 24h
	Now     func() time.Time // inyectable en tests; default time.Now

	mu      sync.Mutex
	fetched time.Time
	// productID → subTypeName ("Normal"/"Foil") → marketPrice
	prices map[string]map[string]float64
}

type tcgGroupsPage struct {
	Results []struct {
		GroupID int `json:"groupId"`
	} `json:"results"`
}

type tcgPricesPage struct {
	Results []struct {
		ProductID   int64    `json:"productId"`
		MarketPrice *float64 `json:"marketPrice"`
		SubTypeName string   `json:"subTypeName"`
	} `json:"results"`
}

func (c *TCGCsv) Price(ctx context.Context, tcgplayerID string, foil bool) (*float64, error) {
	prices, err := c.snapshot(ctx)
	if err != nil {
		return nil, err
	}
	subType := "Normal"
	if foil {
		subType = "Foil"
	}
	if p, ok := prices[tcgplayerID][subType]; ok {
		return &p, nil
	}
	return nil, nil
}

// snapshot devuelve el mapa de precios vigente, refrescándolo si venció.
func (c *TCGCsv) snapshot(ctx context.Context) (map[string]map[string]float64, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	now := time.Now
	if c.Now != nil {
		now = c.Now
	}
	ttl := c.TTL
	if ttl == 0 {
		ttl = 24 * time.Hour
	}
	if c.prices != nil && now().Sub(c.fetched) < ttl {
		return c.prices, nil
	}

	fresh, err := c.fetchAll(ctx)
	if err != nil {
		if c.prices != nil {
			return c.prices, nil // stale antes que nada
		}
		return nil, err
	}
	c.prices, c.fetched = fresh, now()
	return c.prices, nil
}

func (c *TCGCsv) fetchAll(ctx context.Context) (map[string]map[string]float64, error) {
	base := c.BaseURL
	if base == "" {
		base = DefaultTCGCsvBaseURL
	}
	var groups tcgGroupsPage
	if err := c.getJSON(ctx, fmt.Sprintf("%s/tcgplayer/%d/groups", base, riftboundCategoryID), &groups); err != nil {
		return nil, fmt.Errorf("grupos de tcgcsv: %w", err)
	}

	prices := map[string]map[string]float64{}
	for _, g := range groups.Results {
		var page tcgPricesPage
		url := fmt.Sprintf("%s/tcgplayer/%d/%d/prices", base, riftboundCategoryID, g.GroupID)
		if err := c.getJSON(ctx, url, &page); err != nil {
			return nil, fmt.Errorf("precios del grupo %d: %w", g.GroupID, err)
		}
		for _, p := range page.Results {
			if p.MarketPrice == nil {
				continue
			}
			id := strconv.FormatInt(p.ProductID, 10)
			if prices[id] == nil {
				prices[id] = map[string]float64{}
			}
			prices[id][p.SubTypeName] = *p.MarketPrice
		}
	}
	return prices, nil
}

func (c *TCGCsv) getJSON(ctx context.Context, url string, dst any) error {
	httpc := c.HTTP
	if httpc == nil {
		httpc = &http.Client{Timeout: 60 * time.Second}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", priceUserAgent)
	resp, err := httpc.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d de tcgcsv (%s)", resp.StatusCode, url)
	}
	return json.NewDecoder(resp.Body).Decode(dst)
}
