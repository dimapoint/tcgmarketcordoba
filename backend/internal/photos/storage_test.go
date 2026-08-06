package photos

import (
	"net/http/httptest"
	"testing"
)

func TestNewS3StorageStripsSchemeAndTrailingSlash(t *testing.T) {
	s, err := NewS3Storage("https://t3.storageapi.dev", "ak", "sk", "my-bucket", "https://example.com/")
	if err != nil {
		t.Fatal(err)
	}
	if got := s.Client.EndpointURL().Host; got != "t3.storageapi.dev" {
		t.Fatalf("endpoint host = %q", got)
	}
	if s.PublicURL != "https://example.com" {
		t.Fatalf("PublicURL = %q, want trailing slash trimmed", s.PublicURL)
	}
	if s.Bucket != "my-bucket" {
		t.Fatalf("Bucket = %q", s.Bucket)
	}
}

func TestProxyServeRejectsEmptyOrTraversalPath(t *testing.T) {
	p := &Proxy{Bucket: "my-bucket"}
	for _, path := range []string{"", "listings/../../etc/passwd"} {
		req := httptest.NewRequest("GET", "/photos/"+path, nil)
		req.SetPathValue("path", path)
		w := httptest.NewRecorder()
		p.Serve(w, req)
		if w.Code != 404 {
			t.Fatalf("path %q: status = %d, want 404", path, w.Code)
		}
	}
}
