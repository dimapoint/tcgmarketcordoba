package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"net/mail"
	"time"

	"tcgmarketcordoba/internal/httpx"
)

const refreshTTL = 30 * 24 * time.Hour

type Handler struct {
	Store  Store
	Tokens TokenIssuer
	Google GoogleVerifier // nil si GOOGLE_CLIENT_ID no está configurado
}

type credentials struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type userJSON struct {
	ID      string `json:"id"`
	Email   string `json:"email"`
	IsAdmin bool   `json:"is_admin"`
}

type authResponse struct {
	AccessToken  string   `json:"access_token"`
	RefreshToken string   `json:"refresh_token"`
	User         userJSON `json:"user"`
}

func (h *Handler) SignUp(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := httpx.Decode(r, &c); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	if _, err := mail.ParseAddress(c.Email); err != nil || len(c.Password) < 8 {
		httpx.Error(w, http.StatusUnprocessableEntity,
			"email inválido o contraseña menor a 8 caracteres")
		return
	}
	hash, err := HashPassword(c.Password)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	u, err := h.Store.CreateUser(r.Context(), c.Email, hash)
	if errors.Is(err, ErrEmailTaken) {
		httpx.Error(w, http.StatusConflict, "el email ya está registrado")
		return
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	h.respondWithTokens(w, r, http.StatusCreated, u)
}

func (h *Handler) SignIn(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := httpx.Decode(r, &c); err != nil {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	u, err := h.Store.UserByEmail(r.Context(), c.Email)
	if err != nil || !CheckPassword(u.PasswordHash, c.Password) {
		httpx.Error(w, http.StatusUnauthorized, "credenciales inválidas")
		return
	}
	h.respondWithTokens(w, r, http.StatusOK, u)
}

func (h *Handler) GoogleSignIn(w http.ResponseWriter, r *http.Request) {
	if h.Google == nil {
		httpx.Error(w, http.StatusServiceUnavailable,
			"el login con Google no está configurado")
		return
	}
	var body struct {
		IDToken string `json:"id_token"`
	}
	if err := httpx.Decode(r, &body); err != nil || body.IDToken == "" {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	email, err := h.Google.VerifyIDToken(r.Context(), body.IDToken)
	if err != nil {
		httpx.Error(w, http.StatusUnauthorized, "token de Google inválido")
		return
	}
	u, err := h.Store.UserByEmail(r.Context(), email)
	if errors.Is(err, ErrNotFound) {
		u, err = h.Store.CreateGoogleUser(r.Context(), email)
	}
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	h.respondWithTokens(w, r, http.StatusOK, u)
}

func (h *Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := httpx.Decode(r, &body); err != nil || body.RefreshToken == "" {
		httpx.Error(w, http.StatusBadRequest, "cuerpo inválido")
		return
	}
	sum := sha256.Sum256([]byte(body.RefreshToken))
	userID, err := h.Store.ConsumeRefreshToken(r.Context(), hex.EncodeToString(sum[:]))
	if err != nil {
		httpx.Error(w, http.StatusUnauthorized, "refresh token inválido")
		return
	}
	u, err := h.Store.UserByID(r.Context(), userID)
	if err != nil {
		httpx.Error(w, http.StatusUnauthorized, "usuario no encontrado")
		return
	}
	h.respondWithTokens(w, r, http.StatusOK, u)
}

func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	u, err := h.Store.UserByID(r.Context(), UserID(r.Context()))
	if err != nil {
		httpx.Error(w, http.StatusNotFound, "usuario no encontrado")
		return
	}
	httpx.JSON(w, http.StatusOK, userJSON{ID: u.ID, Email: u.Email, IsAdmin: u.IsAdmin})
}

func (h *Handler) respondWithTokens(w http.ResponseWriter, r *http.Request, status int, u User) {
	access, err := h.Tokens.Issue(u.ID)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	raw := make([]byte, 32)
	rand.Read(raw)
	refresh := hex.EncodeToString(raw)
	sum := sha256.Sum256([]byte(refresh))
	if err := h.Store.SaveRefreshToken(r.Context(), u.ID, hex.EncodeToString(sum[:]),
		time.Now().Add(refreshTTL)); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "error interno")
		return
	}
	httpx.JSON(w, status, authResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         userJSON{ID: u.ID, Email: u.Email, IsAdmin: u.IsAdmin},
	})
}
