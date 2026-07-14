package httpx

import (
	"net/http/httptest"
	"testing"
	"time"
)

func TestCursorRoundTrip(t *testing.T) {
	now := time.Now().UTC()
	id := "uuid-1234"
	enc := EncodeCursor(now, id)
	decT, decID, err := DecodeCursor(enc)
	if err != nil {
		t.Fatal(err)
	}
	if !decT.Equal(now) {
		t.Errorf("expected %v, got %v", now, decT)
	}
	if decID != id {
		t.Errorf("expected %s, got %s", id, decID)
	}
}

func TestDecodeInvalidCursor(t *testing.T) {
	_, _, err := DecodeCursor("invalid-base64-!")
	if err == nil {
		t.Error("expected error for invalid base64")
	}
	_, _, err = DecodeCursor("")
	if err == nil {
		t.Error("expected error for empty cursor")
	}
}

func TestParsePagination(t *testing.T) {
	now := time.Now().UTC()
	id := "uuid-1234"
	validCursor := EncodeCursor(now, id)

	tests := []struct {
		name       string
		query      string
		wantLimit  int
		wantCursor bool
	}{
		{"default", "", 20, false},
		{"custom limit", "?limit=10", 10, false},
		{"limit too high", "?limit=100", 50, false},
		{"invalid limit", "?limit=abc", 20, false},
		{"valid cursor", "?cursor=" + validCursor, 20, true},
		{"invalid cursor", "?cursor=invalid", 20, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", "/"+tt.query, nil)
			cTime, _, limit := ParsePagination(req)
			if limit != tt.wantLimit {
				t.Errorf("limit = %d, want %d", limit, tt.wantLimit)
			}
			if tt.wantCursor && cTime == nil {
				t.Errorf("expected cursor, got nil")
			}
			if !tt.wantCursor && cTime != nil {
				t.Errorf("expected nil cursor, got %v", cTime)
			}
		})
	}
}
