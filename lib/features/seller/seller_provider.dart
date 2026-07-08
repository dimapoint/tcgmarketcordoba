import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/seller_page.dart';
import 'seller_repository.dart';

final sellerPageProvider =
    FutureProvider.autoDispose.family<SellerPage, String>((ref, username) {
  return ref.watch(sellerRepositoryProvider).fetch(username);
});
