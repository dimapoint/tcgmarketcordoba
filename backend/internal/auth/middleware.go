package auth

import (
	"context"
	"net/http"
	"strings"

	"tcgmarketcordoba/internal/httpx"
)

type ctxKey struct{}

// UserID devuelve el id del usuario autenticado, o "" si no hay.
func UserID(ctx context.Context) string {
	id, _ := ctx.Value(ctxKey{}).(string)
	return id
}

func Middleware(tokens TokenIssuer) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
			if !ok {
				httpx.Error(w, http.StatusUnauthorized, "falta el token")
				return
			}
			userID, err := tokens.Verify(raw)
			if err != nil {
				httpx.Error(w, http.StatusUnauthorized, "token inválido")
				return
			}
			next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, userID)))
		})
	}
}
