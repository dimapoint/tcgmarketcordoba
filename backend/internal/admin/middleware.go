package admin

import (
	"net/http"

	"tcgmarketcordoba/internal/auth"
	"tcgmarketcordoba/internal/httpx"
)

// Require exige que el usuario autenticado sea admin. Asume que
// auth.Middleware ya corrió (hay user id en el context). Consulta la DB en
// cada request: revocar admin surte efecto inmediato, sin esperar al JWT.
func Require(store Store) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			isAdmin, err := store.IsAdmin(r.Context(), auth.UserID(r.Context()))
			if err != nil {
				httpx.Error(w, http.StatusInternalServerError, "error interno")
				return
			}
			if !isAdmin {
				httpx.Error(w, http.StatusForbidden, "solo para administradores")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
