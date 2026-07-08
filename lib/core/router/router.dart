import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/browse/screens/browse_screen.dart';
import '../../features/browse/screens/listing_detail_screen.dart';
import '../../features/my_listings/screens/my_listings_screen.dart';
import '../../features/onboarding/onboarding_content.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/post_listing/screens/post_listing_screen.dart';
import '../../features/post_wanted/screens/post_wanted_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/seller/screens/seller_screen.dart';
import '../../features/wanted/screens/wanted_detail_screen.dart';
import '../../features/wanted/screens/wanted_screen.dart';
import '../../shared/widgets/scaffold_with_nav.dart';
import '../api/api_provider.dart';
import '../onboarding/onboarding_provider.dart';

/// Puentea el stream de sesión del ApiClient a un Listenable para que
/// GoRouter re-evalúe el redirect sin recrear el router.
class SessionRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;
  SessionRefreshNotifier(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

const _protectedPrefixes = ['/post', '/wanted/new', '/my-listings', '/profile'];

/// Decisión de redirect pura, testeable sin widgets.
@visibleForTesting
String? computeRedirect({
  required bool loggedIn,
  required bool hasSeenOnboarding,
  required Uri uri,
  required String matchedLocation,
}) {
  final isProtected =
      _protectedPrefixes.any((r) => matchedLocation.startsWith(r));
  final isAuthRoute =
      matchedLocation == '/sign-in' || matchedLocation == '/sign-up';
  final onOnboarding = matchedLocation == '/onboarding';

  if (isProtected && !loggedIn) {
    return Uri(path: '/sign-in', queryParameters: {'from': uri.toString()})
        .toString();
  }
  if (loggedIn && !hasSeenOnboarding && !onOnboarding) {
    return '/onboarding';
  }
  if (onOnboarding && (hasSeenOnboarding || !loggedIn)) {
    return '/';
  }
  if (isAuthRoute && loggedIn) {
    final from = uri.queryParameters['from'];
    final safe = from != null &&
        from.startsWith('/') &&
        !from.startsWith('//') &&
        !from.startsWith('/sign-');
    return safe ? from : '/';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // apiClientProvider se overridea con un valor fijo en main.dart, así que
  // este Provider corre una sola vez: un único GoRouter por sesión de app.
  final api = ref.watch(apiClientProvider);
  final onboarding = ref.watch(onboardingStoreProvider);
  final refresh = SessionRefreshNotifier(api.onSessionChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => computeRedirect(
      // Lectura sincrónica: nunca hay estado "cargando" ambiguo.
      loggedIn: api.session != null,
      hasSeenOnboarding:
          onboarding.lastSeenVersion() >= kOnboardingLatestVersion,
      uri: state.uri,
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(path: '/',            builder: (c, s) => const BrowseScreen()),
          GoRoute(path: '/wanted',      builder: (c, s) => const WantedScreen()),
          GoRoute(path: '/wanted/new',  builder: (c, s) =>
              PostWantedScreen(initialQuery: s.uri.queryParameters['q'])),
          GoRoute(path: '/post',        builder: (c, s) => const PostListingScreen()),
          GoRoute(path: '/my-listings', builder: (c, s) => const MyListingsScreen()),
          GoRoute(path: '/profile',     builder: (c, s) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/listings/:id',
        builder: (c, s) => ListingDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/buy-orders/:id',
        builder: (c, s) => WantedDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/u/:username',
        builder: (c, s) =>
            SellerScreen(username: s.pathParameters['username']!),
      ),
      GoRoute(path: '/sign-in',    builder: (c, s) => const SignInScreen()),
      GoRoute(path: '/sign-up',    builder: (c, s) => const SignUpScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
    ],
  );
});
