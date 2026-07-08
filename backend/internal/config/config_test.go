package config

import "testing"

func TestLoadRequiresDatabaseURL(t *testing.T) {
	t.Setenv("DATABASE_URL", "")
	t.Setenv("JWT_SECRET", "s")
	if _, err := Load(); err == nil {
		t.Fatal("expected error when DATABASE_URL missing")
	}
}

func TestPublicURLDefault(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "s")
	t.Setenv("PUBLIC_URL", "")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.PublicURL != "http://localhost:8080" {
		t.Errorf("PublicURL = %q", cfg.PublicURL)
	}
}

func TestPublicURLFromEnvTrimsTrailingSlash(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "s")
	t.Setenv("PUBLIC_URL", "https://tcgmarketcordoba.fly.dev/")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.PublicURL != "https://tcgmarketcordoba.fly.dev" {
		t.Errorf("PublicURL = %q", cfg.PublicURL)
	}
}

func TestLoadDefaultsPort(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://x")
	t.Setenv("JWT_SECRET", "s")
	t.Setenv("PORT", "")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != "8080" {
		t.Fatalf("Port = %q, want 8080", cfg.Port)
	}
}
