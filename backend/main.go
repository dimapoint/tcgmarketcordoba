package main

import (
	"context"
	"log"
	"net/http"

	"tcgmarketcordoba/internal/config"
	"tcgmarketcordoba/internal/db"
	"tcgmarketcordoba/internal/httpx"
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

	log.Printf("API listening on :%s", cfg.Port)
	log.Fatal(http.ListenAndServe(":"+cfg.Port, httpx.CORS(mux)))
}
