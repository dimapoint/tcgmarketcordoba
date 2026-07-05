import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api/api_client.dart';
import 'core/api/api_provider.dart';
import 'core/api/token_store.dart';
import 'core/onboarding/onboarding_provider.dart';
import 'core/onboarding/onboarding_store.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(
    baseUrl: dotenv.env['API_URL']!,
    tokens: TokenStore(prefs),
  );
  final onboardingStore = OnboardingStore(prefs);

  runApp(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      onboardingStoreProvider.overrideWithValue(onboardingStore),
    ],
    child: const App(),
  ));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'TCGMarket Córdoba',
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
    );
  }
}
