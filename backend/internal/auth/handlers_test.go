package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type fakeStore struct {
	usersByEmail map[string]User
	refresh      map[string]string
	nextID       int
}

func newFakeStore() *fakeStore {
	return &fakeStore{usersByEmail: map[string]User{}, refresh: map[string]string{}}
}

func (f *fakeStore) CreateUser(_ context.Context, email, hash string) (User, error) {
	if _, ok := f.usersByEmail[email]; ok {
		return User{}, ErrEmailTaken
	}
	f.nextID++
	u := User{ID: fmt.Sprintf("user-%d", f.nextID), Email: email, PasswordHash: hash}
	f.usersByEmail[email] = u
	return u, nil
}

func (f *fakeStore) UserByEmail(_ context.Context, email string) (User, error) {
	u, ok := f.usersByEmail[email]
	if !ok {
		return User{}, ErrNotFound
	}
	return u, nil
}

func (f *fakeStore) UserByID(_ context.Context, id string) (User, error) {
	for _, u := range f.usersByEmail {
		if u.ID == id {
			return u, nil
		}
	}
	return User{}, ErrNotFound
}

func (f *fakeStore) SaveRefreshToken(_ context.Context, userID, tokenHash string, _ time.Time) error {
	f.refresh[tokenHash] = userID
	return nil
}

func (f *fakeStore) ConsumeRefreshToken(_ context.Context, tokenHash string) (string, error) {
	uid, ok := f.refresh[tokenHash]
	if !ok {
		return "", ErrNotFound
	}
	delete(f.refresh, tokenHash)
	return uid, nil
}

func testHandler() *Handler {
	return &Handler{
		Store:  newFakeStore(),
		Tokens: TokenIssuer{Secret: []byte("test-secret"), TTL: time.Minute},
	}
}

type authRes struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	User         struct {
		ID    string `json:"id"`
		Email string `json:"email"`
	} `json:"user"`
}

func doJSON(t *testing.T, fn http.HandlerFunc, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest("POST", "/", strings.NewReader(body))
	rec := httptest.NewRecorder()
	fn(rec, req)
	return rec
}

func TestSignUpReturnsTokens(t *testing.T) {
	h := testHandler()
	rec := doJSON(t, h.SignUp, `{"email":"a@b.com","password":"12345678"}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("code = %d, body = %s", rec.Code, rec.Body)
	}
	var res authRes
	if err := json.Unmarshal(rec.Body.Bytes(), &res); err != nil {
		t.Fatal(err)
	}
	if res.AccessToken == "" || res.RefreshToken == "" || res.User.Email != "a@b.com" {
		t.Fatalf("unexpected response: %s", rec.Body)
	}
}

func TestSignUpRejectsShortPassword(t *testing.T) {
	h := testHandler()
	rec := doJSON(t, h.SignUp, `{"email":"a@b.com","password":"corta"}`)
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("code = %d, want 422", rec.Code)
	}
}

func TestSignInWrongPassword(t *testing.T) {
	h := testHandler()
	doJSON(t, h.SignUp, `{"email":"a@b.com","password":"12345678"}`)
	rec := doJSON(t, h.SignIn, `{"email":"a@b.com","password":"incorrecta"}`)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("code = %d, want 401", rec.Code)
	}
}

func TestRefreshRotatesToken(t *testing.T) {
	h := testHandler()
	rec := doJSON(t, h.SignUp, `{"email":"a@b.com","password":"12345678"}`)
	var first authRes
	json.Unmarshal(rec.Body.Bytes(), &first)

	rec2 := doJSON(t, h.Refresh, `{"refresh_token":"`+first.RefreshToken+`"}`)
	if rec2.Code != http.StatusOK {
		t.Fatalf("refresh code = %d, body = %s", rec2.Code, rec2.Body)
	}

	// el token viejo quedó consumido
	rec3 := doJSON(t, h.Refresh, `{"refresh_token":"`+first.RefreshToken+`"}`)
	if rec3.Code != http.StatusUnauthorized {
		t.Fatalf("reused refresh code = %d, want 401", rec3.Code)
	}
}
