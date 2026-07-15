/// Tiempo relativo en español, sin dependencias externas.
String relativeTime(DateTime dateTime, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.toUtc().difference(dateTime.toUtc());

  if (diff.inMinutes < 1) return 'recién';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return 'hace $m min';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'hace $h h';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return 'hace $d ${d == 1 ? "día" : "días"}';
  }
  if (diff.inDays < 60) {
    final w = diff.inDays ~/ 7;
    return 'hace $w ${w == 1 ? "semana" : "semanas"}';
  }

  const months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  final local = dateTime.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
