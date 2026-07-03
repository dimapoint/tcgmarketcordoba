package photos

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestSupabaseStorageUpload(t *testing.T) {
	var gotPath, gotAuth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotAuth = r.Header.Get("Authorization")
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	s := &SupabaseStorage{BaseURL: srv.URL, ServiceKey: "sk", Bucket: "listing-photos"}
	url, err := s.Upload(context.Background(), "listings/l1/1.jpg", "image/jpeg",
		strings.NewReader("fake-bytes"))
	if err != nil {
		t.Fatal(err)
	}
	if gotPath != "/storage/v1/object/listing-photos/listings/l1/1.jpg" {
		t.Fatalf("path = %q", gotPath)
	}
	if gotAuth != "Bearer sk" {
		t.Fatalf("auth = %q", gotAuth)
	}
	want := srv.URL + "/storage/v1/object/public/listing-photos/listings/l1/1.jpg"
	if url != want {
		t.Fatalf("url = %q, want %q", url, want)
	}
}
