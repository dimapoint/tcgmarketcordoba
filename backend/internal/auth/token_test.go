package auth

import (
	"testing"
	"time"
)

func TestTokenRoundTrip(t *testing.T) {
	issuer := TokenIssuer{Secret: []byte("s3cr3t"), TTL: time.Minute}
	tok, err := issuer.Issue("user-123")
	if err != nil {
		t.Fatal(err)
	}
	uid, err := issuer.Verify(tok)
	if err != nil {
		t.Fatal(err)
	}
	if uid != "user-123" {
		t.Fatalf("uid = %q", uid)
	}
}

func TestExpiredTokenRejected(t *testing.T) {
	issuer := TokenIssuer{Secret: []byte("s3cr3t"), TTL: -time.Minute}
	tok, _ := issuer.Issue("user-123")
	if _, err := issuer.Verify(tok); err == nil {
		t.Fatal("expired token accepted")
	}
}

func TestWrongSecretRejected(t *testing.T) {
	tok, _ := TokenIssuer{Secret: []byte("a"), TTL: time.Minute}.Issue("u")
	if _, err := (TokenIssuer{Secret: []byte("b"), TTL: time.Minute}).Verify(tok); err == nil {
		t.Fatal("token with wrong secret accepted")
	}
}
