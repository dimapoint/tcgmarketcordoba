package httpx

import (
	"encoding/base64"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type PageResponse struct {
	Data       any    `json:"data"`
	NextCursor string `json:"next_cursor"`
}

func PageJSON(w http.ResponseWriter, status int, data any, nextCursor string) {
	JSON(w, status, PageResponse{
		Data:       data,
		NextCursor: nextCursor,
	})
}

func EncodeCursor(t time.Time, id string) string {
	raw := fmt.Sprintf("%s|%s", t.Format(time.RFC3339Nano), id)
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

func DecodeCursor(s string) (time.Time, string, error) {
	if s == "" {
		return time.Time{}, "", fmt.Errorf("empty cursor")
	}
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return time.Time{}, "", err
	}
	parts := strings.SplitN(string(b), "|", 2)
	if len(parts) != 2 {
		return time.Time{}, "", fmt.Errorf("invalid cursor format")
	}
	t, err := time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return time.Time{}, "", err
	}
	return t, parts[1], nil
}

func ParsePagination(r *http.Request) (cursorTime *time.Time, cursorID string, limit int) {
	limit = 20
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil {
			if parsed > 0 && parsed <= 50 {
				limit = parsed
			} else if parsed > 50 {
				limit = 50
			}
		}
	}
	if c := r.URL.Query().Get("cursor"); c != "" {
		if t, id, err := DecodeCursor(c); err == nil {
			cursorTime = &t
			cursorID = id
		}
	}
	return
}
