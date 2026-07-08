/// El backend manda rutas relativas (p. ej. /card-images/...) que sirve él
/// mismo como proxy del CDN de Riot, que no habilita CORS. En web dev la app
/// (:5003) y la API (:8080) son orígenes distintos, así que siempre se
/// resuelven contra baseUrl.
String? absoluteApiUrl(String? url, String baseUrl) {
  if (url == null || !url.startsWith('/')) return url;
  return '$baseUrl$url';
}

/// Variante redimensionada server-side: el proxy /card-images pasa ?w= al CDN
/// (Sanity), así las listas piden miniaturas chicas en vez del PNG completo.
String? imageWithWidth(String? url, int width) {
  if (url == null || url.contains('?')) return url;
  return '$url?w=$width';
}
