import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/account/screens/account_screen.dart';
import '../../features/admin/screens/admin_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/browse/screens/browse_screen.dart';
import '../../features/browse/screens/listing_detail_screen.dart';
import '../../features/feedback/screens/feedback_screen.dart';
import '../../features/onboarding/onboarding_content.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/post_listing/screens/post_listing_screen.dart';
import '../../features/post_wanted/screens/post_wanted_screen.dart';
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

const _protectedPrefixes = [
  '/post',
  '/wanted/new',
  '/account',
  '/admin',
  '/feedback',
];

/// Decisión de redirect pura, testeable sin widgets.
@visibleForTesting
String? computeRedirect({
  required bool loggedIn,
  required bool hasSeenOnboarding,
  bool isAdmin = false,
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
  if (matchedLocation.startsWith('/admin') && loggedIn && !isAdmin) {
    return '/';
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

/// Transición compartida de todas las rutas: fade + slide sutil hacia arriba.
/// Con animaciones deshabilitadas el fade dura igual pero GoRouter respeta
/// el flag a nivel MediaQuery (las transiciones se saltean solas).
CustomTransitionPage<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.of(context).disableAnimations) return child;
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

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
      isAdmin: api.session?.user.isAdmin ?? false,
      uri: state.uri,
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(path: '/',            pageBuilder: (c, s) => _page(s, const BrowseScreen())),
          GoRoute(path: '/wanted',      pageBuilder: (c, s) => _page(s, const WantedScreen())),
          GoRoute(path: '/wanted/new',  pageBuilder: (c, s) => _page(s,
              PostWantedScreen(initialQuery: s.uri.queryParameters['q']))),
          GoRoute(path: '/post',        pageBuilder: (c, s) => _page(s, const PostListingScreen())),
          GoRoute(path: '/account',     pageBuilder: (c, s) => _page(s,
              AccountScreen(initialTab: s.uri.queryParameters['tab']))),
          GoRoute(path: '/feedback',    pageBuilder: (c, s) => _page(s, const FeedbackScreen())),
        ],
      ),
      // Deep links cortos y compartibles: no chocan con las rutas JSON de la
      // API (/listings/{id}, /buy-orders/{id}) cuando el backend sirve el SPA.
      GoRoute(
        path: '/l/:id',
        pageBuilder: (c, s) =>
            _page(s, ListingDetailScreen(id: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/b/:id',
        pageBuilder: (c, s) =>
            _page(s, WantedDetailScreen(id: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/u/:username',
        pageBuilder: (c, s) =>
            _page(s, SellerScreen(username: s.pathParameters['username']!)),
      ),
      // Alias viejos (pre path-URLs): redirigen a los paths cortos.
      GoRoute(
        path: '/listings/:id',
        redirect: (c, s) => '/l/${s.pathParameters['id']}',
      ),
      GoRoute(
        path: '/buy-orders/:id',
        redirect: (c, s) => '/b/${s.pathParameters['id']}',
      ),
      // Mis Cartas y Perfil se unificaron en /account (tab "Mis cartas" /
      // "Perfil"); estos alias mantienen vivos los bookmarks viejos.
      GoRoute(
        path: '/my-listings',
        redirect: (c, s) => '/account',
      ),
      GoRoute(
        path: '/profile',
        redirect: (c, s) => '/account?tab=perfil',
      ),
      GoRoute(path: '/admin',      pageBuilder: (c, s) => _page(s, const AdminScreen())),
      GoRoute(path: '/sign-in',    pageBuilder: (c, s) => _page(s, const SignInScreen())),
      GoRoute(path: '/sign-up',    pageBuilder: (c, s) => _page(s, const SignUpScreen())),
      GoRoute(path: '/onboarding', pageBuilder: (c, s) => _page(s, const OnboardingScreen())),
    ],
  );
});
