import 'listing.dart';
import 'wanted_order.dart';

/// Perfil público de un vendedor: solo username y ciudad, nunca contactos
/// (esos siguen detrás de /profiles/{id}/contacts, que requiere login).
class SellerProfile {
  final String username;
  final String? city;
  const SellerProfile({required this.username, this.city});

  factory SellerProfile.fromJson(Map<String, dynamic> j) => SellerProfile(
        username: j['username'] as String,
        city: j['city'] as String?,
      );
}

class SellerPage {
  final SellerProfile profile;
  final List<Listing> listings;
  final List<WantedOrder> buyOrders;
  const SellerPage({
    required this.profile,
    required this.listings,
    required this.buyOrders,
  });

  factory SellerPage.fromJson(Map<String, dynamic> j) => SellerPage(
        profile: SellerProfile.fromJson(j['profile'] as Map<String, dynamic>),
        listings: (j['listings'] as List<dynamic>? ?? [])
            .map((e) => Listing.fromJson(e as Map<String, dynamic>))
            .toList(),
        buyOrders: (j['buy_orders'] as List<dynamic>? ?? [])
            .map((e) => WantedOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
