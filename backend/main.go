package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/buyorders"
	"tcgmarketcordoba/internal/cards"
	"tcgmarketcordoba/internal/config"
	"tcgmarketcordoba/internal/db"
	"tcgmarketcordoba/internal/httpx"
	"tcgmarketcordoba/internal/listings"
	"tcgmarketcordoba/internal/photos"
	"tcgmarketcordoba/internal/profiles"
	"tcgmarketcordoba/internal/webapp"
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
	mux.Handle("POST /listings", requireAuth(http.HandlerFunc(listingH.Create)))
	mux.Handle("PATCH /listings/{id}", requireAuth(http.HandlerFunc(listingH.Patch)))
	mux.Handle("GET /me/listings", requireAuth(http.HandlerFunc(listingH.MyListings)))

	cardH := &cards.Handler{Store: cards.NewPgStore(pool)}
	mux.HandleFunc("GET /cards/search", cardH.Search)

	buyOrderH := &buyorders.Handler{Store: buyorders.NewPgStore(pool)}
	mux.HandleFunc("GET /buy-orders", buyOrderH.List)
	mux.HandleFunc("GET /buy-orders/{id}", buyOrderH.Get)
	mux.Handle("POST /buy-orders", requireAuth(http.HandlerFunc(buyOrderH.Create)))
	mux.Handle("PATCH /buy-orders/{id}", requireAuth(http.HandlerFunc(buyOrderH.Patch)))
	mux.Handle("GET /me/buy-orders", requireAuth(http.HandlerFunc(buyOrderH.MyBuyOrders)))

	profileH := &profiles.Handler{Store: profiles.NewPgStore(pool)}
	mux.HandleFunc("GET /cities", profileH.ListCities)
	mux.HandleFunc("GET /profiles/{id}/contacts", profileH.SellerContacts)
	mux.Handle("GET /me/profile", requireAuth(http.HandlerFunc(profileH.Me)))
	mux.Handle("PATCH /me/profile", requireAuth(http.HandlerFunc(profileH.UpdateMe)))
	mux.Handle("GET /me/contacts", requireAuth(http.HandlerFunc(profileH.MyContacts)))
	mux.Handle("PUT /me/contacts", requireAuth(http.HandlerFunc(profileH.PutContact)))
	mux.Handle("DELETE /me/contacts/{id}", requireAuth(http.HandlerFunc(profileH.DeleteContact)))

	photoH := &photos.Handler{
		Store: photos.NewPgStore(pool),
		Uploader: &photos.SupabaseStorage{
			BaseURL:    cfg.SupabaseURL,
			ServiceKey: cfg.SupabaseServiceKey,
			Bucket:     "listing-photos",
		},
	}
	mux.Handle("POST /listings/{id}/photos", requireAuth(http.HandlerFunc(photoH.Upload)))

	// En producción el mismo server sirve el build web de Flutter; las rutas
	// de API registradas arriba tienen precedencia sobre el catch-all "/".
	if cfg.WebDir != "" {
		mux.Handle("/", webapp.Handler(cfg.WebDir))
	}

	log.Printf("API listening on :%s", cfg.Port)
	log.Fatal(http.ListenAndServe(":"+cfg.Port, httpx.CORS(mux)))
}
