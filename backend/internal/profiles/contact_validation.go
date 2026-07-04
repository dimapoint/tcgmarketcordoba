package profiles

import (
	"errors"
	"regexp"
	"strings"
)

var (
	whatsappRe  = regexp.MustCompile(`^\+?[0-9]{8,15}$`)
	instagramRe = regexp.MustCompile(`^[A-Za-z0-9._]{1,30}$`)
	telegramRe  = regexp.MustCompile(`^[A-Za-z][A-Za-z0-9_]{4,31}$`)
	emailRe     = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)
)

var stripWhatsappFormatting = strings.NewReplacer(" ", "", "-", "", "(", "", ")", "", ".", "")

// normalizeContact limpia y valida el valor de un método de contacto según
// su tipo (whatsapp/instagram/telegram/email). Devuelve el valor listo para
// guardar, o un error con mensaje en español apto para mostrar al usuario.
func normalizeContact(contactType, raw string) (string, error) {
	v := strings.TrimSpace(raw)
	switch contactType {
	case "whatsapp":
		v = stripWhatsappFormatting.Replace(stripURLPrefix(v, "wa.me/"))
		if !whatsappRe.MatchString(v) {
			return "", errors.New("el número de WhatsApp no es válido")
		}
	case "instagram":
		v = stripURLPrefix(v, "instagram.com/")
		if !instagramRe.MatchString(v) {
			return "", errors.New("el usuario de Instagram no es válido")
		}
	case "telegram":
		v = stripURLPrefix(v, "t.me/")
		if !telegramRe.MatchString(v) {
			return "", errors.New("el usuario de Telegram no es válido")
		}
	case "email":
		if !emailRe.MatchString(v) {
			return "", errors.New("el email no es válido")
		}
	default:
		return "", errors.New("tipo de contacto inválido")
	}
	return v, nil
}

// stripURLPrefix saca un handle "@usuario" o una URL de perfil pegada
// (con o sin protocolo/www, query string o slash final) y deja solo el
// valor relevante (username o, para whatsapp, el número).
func stripURLPrefix(v, hostFragment string) string {
	if idx := strings.Index(strings.ToLower(v), hostFragment); idx != -1 {
		v = v[idx+len(hostFragment):]
	}
	v = strings.TrimPrefix(v, "@")
	v = strings.Trim(v, "/")
	if i := strings.IndexAny(v, "/?"); i != -1 {
		v = v[:i]
	}
	return v
}
