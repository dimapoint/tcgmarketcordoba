import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Stub router — will be replaced in Task 6 (Flutter core: router + bottom nav scaffold).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text(
              'TCGMarket Córdoba',
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    ],
  );
});
