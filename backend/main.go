package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/config"
	"tcgmarketcordoba/internal/db"
	"tcgmarketcordoba/internal/httpx"
	"tcgmarketcordoba/internal/listings"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}

	pool, err := db.Connect(context.Background(), cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	tokens := auth.TokenIssuer{Secret: []byte(cfg.JWTSecret), TTL: 15 * time.Minute}
	requireAuth := auth.Middleware(tokens)

	authH := &auth.Handler{Store: auth.NewPgStore(pool), Tokens: tokens}
	mux.HandleFunc("POST /auth/signup", authH.SignUp)
	mux.HandleFunc("POST /auth/signin", authH.SignIn)
	mux.HandleFunc("POST /auth/refresh", authH.Refresh)
	mux.Handle("GET /auth/me", requireAuth(http.HandlerFunc(authH.Me)))

	listingH := &listings.Handler{Store: listings.NewPgStore(pool)}
	mux.HandleFunc("GET /listings", listingH.List)
	mux.HandleFunc("GET /listings/{id}", listingH.Get)

	log.Printf("API listening on :%s", cfg.Port)
	log.Fatal(http.ListenAndServe(":"+cfg.Port, httpx.CORS(mux)))
}
