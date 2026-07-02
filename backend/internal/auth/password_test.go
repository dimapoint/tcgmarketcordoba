package auth

import "testing"

func TestHashAndCheckPassword(t *testing.T) {
	hash, err := HashPassword("secreto123")
	if err != nil {
		t.Fatal(err)
	}
	if !CheckPassword(hash, "secreto123") {
		t.Fatal("valid password rejected")
	}
	if CheckPassword(hash, "otra") {
		t.Fatal("wrong password accepted")
	}
}
