package feedback

import (
	"errors"
	"net/http"
	"strings"
	"unicode/utf8"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

type Handler struct{ Store Store }

var validCategories = map[string]bool{"bug": true, "sugerencia": true, "otro": true}
var validStatuses = map[string]bool{"nuevo": true, "resuelto": true}

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
	status := r.URL.Query().Get("status")
	if status != "" && !validStatuses[status] {
		httpx.Error(w, http.StatusBadRequest, "estado inválido")
		return
	}
	fs, err := h.Store.List(r.Context(), status)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, fs)
}

func (h *Handler) Patch(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Status string `json:"status"`
	}
	if err := httpx.Decode(r, &b); err != nil || !validStatuses[b.Status] {
		httpx.Error(w, http.StatusBadRequest, "estado inválido")
		return
	}
	err := h.Store.UpdateStatus(r.Context(), r.PathValue("id"), b.Status)
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "mensaje no encontrado")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	err := h.Store.Delete(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpx.Error(w, http.StatusNotFound, "mensaje no encontrado")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
