package photos

import (
	"bytes"
	"context"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"tcgmarketcordoba/internal/auth"
)

type fakeStore struct {
	seller   string
	inserted bool
}

func (f *fakeStore) ListingSeller(_ context.Context, id string) (string, error) {
	if f.seller == "" {
		return "", ErrNotFound
	}
	return f.seller, nil
}

func (f *fakeStore) InsertPhoto(_ context.Context, listingID, url string, order int) error {
	f.inserted = true
	return nil
}

type fakeUploader struct{}

func (fakeUploader) Upload(_ context.Context, path, ct string, body io.Reader) (string, error) {
	return "https://cdn/" + path, nil
}

func multipartReq(t *testing.T, order string) *http.Request {
	t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	mw.WriteField("display_order", order)
	fw, _ := mw.CreateFormFile("file", "foto.jpg")
	fw.Write([]byte("fake-image"))
	mw.Close()

	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("seller-1")
	req := httptest.NewRequest("POST", "/listings/l1/photos", &buf)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+tok)
	req.SetPathValue("id", "l1")
	return req
}

func serve(h *Handler, req *http.Request) *httptest.ResponseRecorder {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	rec := httptest.NewRecorder()
	auth.Middleware(issuer)(http.HandlerFunc(h.Upload)).ServeHTTP(rec, req)
	return rec
}

func TestUploadHappyPath(t *testing.T) {
	store := &fakeStore{seller: "seller-1"}
	h := &Handler{Store: store, Uploader: fakeUploader{}}
	rec := serve(h, multipartReq(t, "1"))
	if rec.Code != http.StatusCreated {
		t.Fatalf("code = %d: %s", rec.Code, rec.Body)
	}
	if !store.inserted {
		t.Fatal("photo row not inserted")
	}
}

func TestUploadNotOwner403(t *testing.T) {
	h := &Handler{Store: &fakeStore{seller: "otro"}, Uploader: fakeUploader{}}
	rec := serve(h, multipartReq(t, "1"))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("code = %d, want 403", rec.Code)
	}
}

func TestUploadBadOrder422(t *testing.T) {
	h := &Handler{Store: &fakeStore{seller: "seller-1"}, Uploader: fakeUploader{}}
	rec := serve(h, multipartReq(t, "7"))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422", rec.Code)
	}
}
