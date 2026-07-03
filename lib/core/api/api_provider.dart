import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// Overrideado en main.dart con la instancia real inicializada.
final apiClientProvider = Provider<ApiClient>(
  (ref) => throw UnimplementedError('apiClientProvider must be overridden'),
);
