package photos

import (
	"context"
	"fmt"
	"io"
	"net/http"
)

type Uploader interface {
	Upload(ctx context.Context, path, contentType string, body io.Reader) (string, error)
}

type SupabaseStorage struct {
	BaseURL    string // ej. https://xyz.supabase.co
	ServiceKey string
	Bucket     string
	HTTP       *http.Client
}

func (s *SupabaseStorage) Upload(ctx context.Context, path, contentType string, body io.Reader) (string, error) {
	url := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.BaseURL, s.Bucket, path)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+s.ServiceKey)
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("x-upsert", "true")

	client := s.HTTP
	if client == nil {
		client = http.DefaultClient
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("storage upload failed: %s: %s", resp.Status, b)
	}
	return fmt.Sprintf("%s/storage/v1/object/public/%s/%s", s.BaseURL, s.Bucket, path), nil
}
