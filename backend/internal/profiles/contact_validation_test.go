package profiles

import "testing"

func TestNormalizeContact(t *testing.T) {
	cases := []struct {
		name    string
		typ     string
		in      string
		want    string
		wantErr bool
	}{
		{"whatsapp con codigo de pais", "whatsapp", "+5493511234567", "+5493511234567", false},
		{"whatsapp solo digitos", "whatsapp", "5493511234567", "5493511234567", false},
		{"whatsapp con formato humano", "whatsapp", "+54 9 351 123-4567", "+5493511234567", false},
		{"whatsapp con link wa.me", "whatsapp", "https://wa.me/5493511234567", "5493511234567", false},
		{"whatsapp con letras", "whatsapp", "no tengo numero", "", true},
		{"whatsapp muy corto", "whatsapp", "12345", "", true},
		{"whatsapp vacio", "whatsapp", "   ", "", true},

		{"instagram con arroba", "instagram", "@usuario.tcg", "usuario.tcg", false},
		{"instagram con url completa", "instagram", "https://instagram.com/usuario.tcg", "usuario.tcg", false},
		{"instagram con url www y query", "instagram", "https://www.instagram.com/usuario.tcg/?hl=es", "usuario.tcg", false},
		{"instagram con espacios", "instagram", "usuario tcg", "", true},

		{"telegram con arroba", "telegram", "@usuario_tcg", "usuario_tcg", false},
		{"telegram con url t.me", "telegram", "https://t.me/usuario_tcg", "usuario_tcg", false},
		{"telegram muy corto", "telegram", "@ab", "", true},
		{"telegram empieza con numero", "telegram", "@1usuario", "", true},

		{"email valido", "email", "vendedor@example.com", "vendedor@example.com", false},
		{"email invalido", "email", "no-es-un-email", "", true},

		{"tipo desconocido", "paloma", "x", "", true},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := normalizeContact(c.typ, c.in)
			if c.wantErr {
				if err == nil {
					t.Fatalf("esperaba error, obtuve valor %q", got)
				}
				return
			}
			if err != nil {
				t.Fatalf("error inesperado: %v", err)
			}
			if got != c.want {
				t.Fatalf("got %q, want %q", got, c.want)
			}
		})
	}
}
