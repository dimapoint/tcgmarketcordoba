import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tcgmarketcordoba/shared/widgets/skeleton.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('Skeleton anima con shimmer por defecto', (tester) async {
    await tester.pumpWidget(_wrap(const Skeleton(width: 100, height: 16)));
    expect(find.byType(Shimmer), findsOneWidget);
  });

  testWidgets('Skeleton queda estático con animaciones deshabilitadas',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const Skeleton(width: 100, height: 16), disableAnimations: true),
    );
    expect(find.byType(Shimmer), findsNothing);
  });

  testWidgets('SkeletonGrid muestra varias cards fantasma', (tester) async {
    await tester.pumpWidget(_wrap(const SkeletonGrid()));
    expect(find.byType(ListingCardSkeleton), findsWidgets);
  });

  testWidgets('ListTileSkeleton y DetailSkeleton se construyen',
      (tester) async {
    await tester.pumpWidget(_wrap(const Column(
      children: [ListTileSkeleton(), Expanded(child: DetailSkeleton())],
    )));
    expect(find.byType(ListTileSkeleton), findsOneWidget);
    expect(find.byType(DetailSkeleton), findsOneWidget);
  });

  testWidgets('WantedListSkeleton se construye', (tester) async {
    await tester.pumpWidget(_wrap(const WantedListSkeleton()));
    expect(find.byType(WantedCardSkeleton), findsWidgets);
  });
}
