package feedback

import (
	"net/http"
	"strings"
	"unicode/utf8"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

type Handler struct{ Store Store }

var validCategories = map[string]bool{"bug": true, "sugerencia": true, "otro": true}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Category string `json:"category"`
		Message  string `json:"message"`
	}
	if err := httpx.Decode(r, &b); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if !validCategories[b.Category] {
		httpx.Error(w, http.StatusBadRequest, "categoría inválida")
		return
	}
	msg := strings.TrimSpace(b.Message)
	if msg == "" {
		httpx.Error(w, http.StatusBadRequest, "el mensaje no puede estar vacío")
		return
	}
	if utf8.RuneCountInString(msg) > 2000 {
		httpx.Error(w, http.StatusBadRequest, "el mensaje es demasiado largo")
		return
	}
	if err := h.Store.Create(r.Context(), auth.UserID(r.Context()), b.Category, msg); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	fs, err := h.Store.List(r.Context())
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, fs)
}
