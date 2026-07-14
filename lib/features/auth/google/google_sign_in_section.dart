import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../auth_provider.dart';
import 'google_button_stub.dart'
    if (dart.library.js_interop) 'google_button_web.dart';

/// OAuth client ID de Google (público). Se overridea en main.dart con el
/// valor del .env; null u vacío desactiva el login con Google.
final googleClientIdProvider = Provider<String?>((_) => null);

/// Inicializa el plugin una sola vez y canjea cada sign-in de Google por una
/// sesión propia. Vive en el ProviderScope raíz para que el listener siga
/// válido aunque las pantallas de auth se desmonten.
final googleAuthInitProvider = Provider<bool>((ref) {
  final clientId = ref.watch(googleClientIdProvider);
  if (clientId == null || clientId.isEmpty) return false;
  _initGoogleSignIn(ref, clientId);
  return true;
});

Future<void> _initGoogleSignIn(Ref ref, String clientId) async {
  try {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(clientId: clientId);
    signIn.authenticationEvents.listen((event) {
      if (event is! GoogleSignInAuthenticationEventSignIn) return;
      final idToken = event.user.authentication.idToken;
      if (idToken == null) return;
      ref.read(authActionsProvider.notifier).signInWithGoogle(idToken);
    }, onError: (Object e) => debugPrint('google sign-in: $e'));
    // En plataformas con sesión nativa recupera la cuenta sin interacción.
    unawaited(signIn.attemptLightweightAuthentication());
  } catch (e) {
    debugPrint('google sign-in init: $e');
  }
}

/// Divisor "o" + botón de Google. No renderiza nada si el client id no está
/// configurado, así la app funciona sin credenciales de Google Cloud.
class GoogleSignInSection extends ConsumerWidget {
  const GoogleSignInSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(googleAuthInitProvider)) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('o', style: Theme.of(context).textTheme.bodySmall),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 8),
        if (kIsWeb)
          Center(child: renderGoogleButton())
        else
          OutlinedButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Continuar con Google'),
            onPressed: () async {
              try {
                await GoogleSignIn.instance.authenticate();
              } catch (e) {
                debugPrint('google sign-in: $e');
              }
            },
          ),
      ],
    );
  }
}
