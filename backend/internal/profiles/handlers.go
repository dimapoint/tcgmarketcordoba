package profiles

import (
	"errors"
	"net/http"
	"strings"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

var validContactTypes = map[string]bool{
	"whatsapp": true, "instagram": true, "email": true, "telegram": true,
}

type Handler struct{ Store Store }

func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	p, err := h.Store.Get(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, "perfil no encontrado")
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}

func (h *Handler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Username *string `json:"username"`
		CityID   *string `json:"city_id"`
	}
	if err := httpx.Decode(r, &b); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if b.Username != nil && strings.TrimSpace(*b.Username) == "" {
		httpx.Error(w, http.StatusUnprocessableEntity,
			"el nombre de usuario no puede estar vacío")
		return
	}
	err := h.Store.Update(r.Context(), auth.UserID(r.Context()), b.Username, b.CityID)
	if errors.Is(err, ErrUsernameTaken) {
		httpx.Error(w, http.StatusConflict, "el nombre de usuario ya está en uso")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) MyContacts(w http.ResponseWriter, r *http.Request) {
	cs, err := h.Store.Contacts(r.Context(), auth.UserID(r.Context()))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, cs)
}

func (h *Handler) PutContact(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Type  string `json:"type"`
		Value string `json:"value"`
	}
	if err := httpx.Decode(r, &b); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if !validContactTypes[b.Type] || strings.TrimSpace(b.Value) == "" {
		httpx.Error(w, http.StatusUnprocessableEntity, "tipo o valor de contacto inválido")
		return
	}
	if err := h.Store.UpsertContact(r.Context(), auth.UserID(r.Context()), b.Type, b.Value); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) DeleteContact(w http.ResponseWriter, r *http.Request) {
	if err := h.Store.DeleteContact(r.Context(), auth.UserID(r.Context()),
		r.PathValue("id")); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) ListCities(w http.ResponseWriter, r *http.Request) {
	cs, err := h.Store.Cities(r.Context())
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, http.StatusOK, cs)
}
