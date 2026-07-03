import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/browse/screens/browse_screen.dart';
import '../../features/browse/screens/listing_detail_screen.dart';
import '../../features/my_listings/screens/my_listings_screen.dart';
import '../../features/post_listing/screens/post_listing_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../shared/widgets/scaffold_with_nav.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final sessionAsync = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = sessionAsync.valueOrNull != null;
      final protectedRoutes = ['/post', '/my-listings', '/profile'];
      final isProtected =
          protectedRoutes.any((r) => state.matchedLocation.startsWith(r));

      if (isProtected && !isLoggedIn) return '/sign-in';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(path: '/',            builder: (c, s) => const BrowseScreen()),
          GoRoute(path: '/post',        builder: (c, s) => const PostListingScreen()),
          GoRoute(path: '/my-listings', builder: (c, s) => const MyListingsScreen()),
          GoRoute(path: '/profile',     builder: (c, s) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/listings/:id',
        builder: (c, s) => ListingDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/sign-in',  builder: (c, s) => const SignInScreen()),
      GoRoute(path: '/sign-up',  builder: (c, s) => const SignUpScreen()),
    ],
  );
});
