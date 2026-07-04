package profiles

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"tcgmarketcordoba/internal/auth"
)

type fakeStore struct {
	profile  Profile
	contacts []ContactMethod
	updated  map[string]string
}

func (f *fakeStore) Get(_ context.Context, id string) (Profile, error) { return f.profile, nil }
func (f *fakeStore) Update(_ context.Context, id string, username, cityID *string) error {
	if f.updated == nil {
		f.updated = map[string]string{}
	}
	if username != nil {
		if *username == "tomado" {
			return ErrUsernameTaken
		}
		f.updated["username"] = *username
	}
	if cityID != nil {
		f.updated["city_id"] = *cityID
	}
	return nil
}
func (f *fakeStore) Contacts(_ context.Context, id string) ([]ContactMethod, error) {
	return f.contacts, nil
}
func (f *fakeStore) UpsertContact(_ context.Context, id, typ, value string) error { return nil }
func (f *fakeStore) DeleteContact(_ context.Context, profileID, contactID string) error {
	return nil
}
func (f *fakeStore) Cities(_ context.Context) ([]City, error) {
	return []City{{ID: "c1", Name: "Córdoba"}}, nil
}

func authedRequest(method, target, body string) *http.Request {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	tok, _ := issuer.Issue("user-1")
	var r *http.Request
	if body == "" {
		r = httptest.NewRequest(method, target, nil)
	} else {
		r = httptest.NewRequest(method, target, strings.NewReader(body))
	}
	r.Header.Set("Authorization", "Bearer "+tok)
	return r
}

func serveAuthed(h http.HandlerFunc, r *http.Request) *httptest.ResponseRecorder {
	issuer := auth.TokenIssuer{Secret: []byte("s"), TTL: time.Minute}
	rec := httptest.NewRecorder()
	auth.Middleware(issuer)(h).ServeHTTP(rec, r)
	return rec
}

func TestMeReturnsProfile(t *testing.T) {
	h := &Handler{Store: &fakeStore{profile: Profile{ID: "user-1", Username: "dimar"}}}
	rec := serveAuthed(h.Me, authedRequest("GET", "/me/profile", ""))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "dimar") {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
}

func TestUpdateMeUsernameTaken409(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	rec := serveAuthed(h.UpdateMe,
		authedRequest("PATCH", "/me/profile", `{"username":"tomado"}`))
	if rec.Code != http.StatusConflict {
		t.Fatalf("code = %d, want 409", rec.Code)
	}
}

func TestPutContactRejectsInvalidType(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	rec := serveAuthed(h.PutContact,
		authedRequest("PUT", "/me/contacts", `{"type":"paloma","value":"x"}`))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422", rec.Code)
	}
}

func TestPutContactRejectsInvalidWhatsapp(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	rec := serveAuthed(h.PutContact,
		authedRequest("PUT", "/me/contacts", `{"type":"whatsapp","value":"no soy un numero"}`))
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422: %s", rec.Code, rec.Body)
	}
}

func TestPutContactNormalizesInstagramHandle(t *testing.T) {
	store := &fakeStore{}
	h := &Handler{Store: store}
	rec := serveAuthed(h.PutContact,
		authedRequest("PUT", "/me/contacts", `{"type":"instagram","value":"@mi.usuario"}`))
	if rec.Code != http.StatusNoContent {
		t.Fatalf("code = %d, want 204: %s", rec.Code, rec.Body)
	}
}

func TestSellerContactsIsPublic(t *testing.T) {
	h := &Handler{Store: &fakeStore{contacts: []ContactMethod{
		{ID: "c1", Type: "whatsapp", Value: "+549351"},
	}}}
	req := httptest.NewRequest("GET", "/profiles/seller-1/contacts", nil)
	req.SetPathValue("id", "seller-1")
	rec := httptest.NewRecorder()
	h.SellerContacts(rec, req)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "whatsapp") {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
}

func TestListCities(t *testing.T) {
	h := &Handler{Store: &fakeStore{}}
	rec := httptest.NewRecorder()
	h.ListCities(rec, httptest.NewRequest("GET", "/cities", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "Córdoba") {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
}
