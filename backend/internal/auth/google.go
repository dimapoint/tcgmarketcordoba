package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// DefaultTokenInfoURL es el endpoint público de Google que valida id_tokens
// (firma, expiración) y devuelve sus claims.
const DefaultTokenInfoURL = "https://oauth2.googleapis.com"

// GoogleVerifier valida un id_token de Google y devuelve el email verificado.
type GoogleVerifier interface {
	VerifyIDToken(ctx context.Context, idToken string) (string, error)
}

// TokenInfoVerifier valida id_tokens contra el endpoint tokeninfo de Google.
// BaseURL es inyectable para tests (default DefaultTokenInfoURL).
type TokenInfoVerifier struct {
	BaseURL  string
	ClientID string
	HTTP     *http.Client
}

func (v *TokenInfoVerifier) VerifyIDToken(ctx context.Context, idToken string) (string, error) {
	base := v.BaseURL
	if base == "" {
		base = DefaultTokenInfoURL
	}
	client := v.HTTP
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}

	u := base + "/tokeninfo?id_token=" + url.QueryEscape(idToken)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return "", err
	}
	res, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return "", fmt.Errorf("tokeninfo: status %d", res.StatusCode)
	}

	var info struct {
		Aud           string `json:"aud"`
		Email         string `json:"email"`
		EmailVerified string `json:"email_verified"`
	}
	if err := json.NewDecoder(res.Body).Decode(&info); err != nil {
		return "", err
	}
	if info.Aud != v.ClientID {
		return "", fmt.Errorf("tokeninfo: audience %q no coincide", info.Aud)
	}
	if info.EmailVerified != "true" || info.Email == "" {
		return "", fmt.Errorf("tokeninfo: email no verificado")
	}
	return info.Email, nil
}
