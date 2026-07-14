package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func tokenInfoServer(t *testing.T, status int, body string) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/tokeninfo" {
			t.Errorf("path = %s, want /tokeninfo", r.URL.Path)
		}
		if r.URL.Query().Get("id_token") == "" {
			t.Error("missing id_token query param")
		}
		w.WriteHeader(status)
		fmt.Fprint(w, body)
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestTokenInfoVerifierValidToken(t *testing.T) {
	srv := tokenInfoServer(t, 200,
		`{"aud":"client-123","email":"a@b.com","email_verified":"true","sub":"g-1"}`)
	v := &TokenInfoVerifier{BaseURL: srv.URL, ClientID: "client-123"}
	email, err := v.VerifyIDToken(context.Background(), "fake-token")
	if err != nil {
		t.Fatal(err)
	}
	if email != "a@b.com" {
		t.Fatalf("email = %q, want a@b.com", email)
	}
}

func TestTokenInfoVerifierWrongAudience(t *testing.T) {
	srv := tokenInfoServer(t, 200,
		`{"aud":"otro-cliente","email":"a@b.com","email_verified":"true"}`)
	v := &TokenInfoVerifier{BaseURL: srv.URL, ClientID: "client-123"}
	if _, err := v.VerifyIDToken(context.Background(), "fake-token"); err == nil {
		t.Fatal("want error for wrong audience")
	}
}

func TestTokenInfoVerifierUnverifiedEmail(t *testing.T) {
	srv := tokenInfoServer(t, 200,
		`{"aud":"client-123","email":"a@b.com","email_verified":"false"}`)
	v := &TokenInfoVerifier{BaseURL: srv.URL, ClientID: "client-123"}
	if _, err := v.VerifyIDToken(context.Background(), "fake-token"); err == nil {
		t.Fatal("want error for unverified email")
	}
}

func TestTokenInfoVerifierInvalidToken(t *testing.T) {
	// Google responde 400 para tokens inválidos o expirados.
	srv := tokenInfoServer(t, 400, `{"error":"invalid_token"}`)
	v := &TokenInfoVerifier{BaseURL: srv.URL, ClientID: "client-123"}
	if _, err := v.VerifyIDToken(context.Background(), "fake-token"); err == nil {
		t.Fatal("want error for invalid token")
	}
}

// ---- handler ----

func (f *fakeStore) CreateGoogleUser(_ context.Context, email string) (User, error) {
	if _, ok := f.usersByEmail[email]; ok {
		return User{}, ErrEmailTaken
	}
	f.nextID++
	u := User{ID: fmt.Sprintf("user-%d", f.nextID), Email: email}
	f.usersByEmail[email] = u
	return u, nil
}

type fakeVerifier struct {
	email string
	err   error
}

func (f fakeVerifier) VerifyIDToken(_ context.Context, _ string) (string, error) {
	return f.email, f.err
}

func TestGoogleSignInCreatesNewUser(t *testing.T) {
	h := testHandler()
	h.Google = fakeVerifier{email: "a@b.com"}
	rec := doJSON(t, h.GoogleSignIn, `{"id_token":"tok"}`)
	if rec.Code != http.StatusOK {
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

func TestGoogleSignInMatchesExistingUserByEmail(t *testing.T) {
	h := testHandler()
	h.Google = fakeVerifier{email: "a@b.com"}
	rec := doJSON(t, h.SignUp, `{"email":"a@b.com","password":"12345678"}`)
	var signedUp authRes
	json.Unmarshal(rec.Body.Bytes(), &signedUp)

	rec2 := doJSON(t, h.GoogleSignIn, `{"id_token":"tok"}`)
	if rec2.Code != http.StatusOK {
		t.Fatalf("code = %d, body = %s", rec2.Code, rec2.Body)
	}
	var res authRes
	json.Unmarshal(rec2.Body.Bytes(), &res)
	if res.User.ID != signedUp.User.ID {
		t.Fatalf("user id = %s, want %s (misma cuenta)", res.User.ID, signedUp.User.ID)
	}
}

func TestGoogleSignInInvalidToken(t *testing.T) {
	h := testHandler()
	h.Google = fakeVerifier{err: fmt.Errorf("token inválido")}
	rec := doJSON(t, h.GoogleSignIn, `{"id_token":"tok"}`)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("code = %d, want 401", rec.Code)
	}
}

func TestGoogleSignInMissingToken(t *testing.T) {
	h := testHandler()
	h.Google = fakeVerifier{email: "a@b.com"}
	rec := doJSON(t, h.GoogleSignIn, `{}`)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("code = %d, want 400", rec.Code)
	}
}

func TestGoogleSignInNotConfigured(t *testing.T) {
	h := testHandler() // sin verifier
	rec := doJSON(t, h.GoogleSignIn, `{"id_token":"tok"}`)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("code = %d, want 503", rec.Code)
	}
}

func TestPasswordSignInFailsForGoogleOnlyUser(t *testing.T) {
	h := testHandler()
	h.Google = fakeVerifier{email: "a@b.com"}
	doJSON(t, h.GoogleSignIn, `{"id_token":"tok"}`)
	rec := doJSON(t, h.SignIn, `{"email":"a@b.com","password":"loquesea1"}`)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("code = %d, want 401 (cuenta sin contraseña)", rec.Code)
	}
}
