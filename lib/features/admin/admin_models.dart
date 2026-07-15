class AdminStats {
  final int users;
  final int activeListings;
  final int activeBuyOrders;
  final int newUsers7d;
  final int newListings7d;
  final int newBuyOrders7d;

  const AdminStats({
    required this.users,
    required this.activeListings,
    required this.activeBuyOrders,
    required this.newUsers7d,
    required this.newListings7d,
    required this.newBuyOrders7d,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        users: json['users'] as int,
        activeListings: json['active_listings'] as int,
        activeBuyOrders: json['active_buy_orders'] as int,
        newUsers7d: json['new_users_7d'] as int,
        newListings7d: json['new_listings_7d'] as int,
        newBuyOrders7d: json['new_buy_orders_7d'] as int,
      );
}

class AdminUser {
  final String id;
  final String email;
  final String username;
  final String? city;
  final bool isAdmin;
  final DateTime createdAt;
  final int activeListings;
  final int activeBuyOrders;

  const AdminUser({
    required this.id,
    required this.email,
    required this.username,
    this.city,
    required this.isAdmin,
    required this.createdAt,
    required this.activeListings,
    required this.activeBuyOrders,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        city: json['city'] as String?,
        isAdmin: json['is_admin'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        activeListings: json['active_listings'] as int,
        activeBuyOrders: json['active_buy_orders'] as int,
      );
}

class FeedbackItem {
  final String id;
  final String username;
  final String category;
  final String message;
  final String status;
  final DateTime createdAt;

  const FeedbackItem({
    required this.id,
    required this.username,
    required this.category,
    required this.message,
    this.status = 'nuevo',
    required this.createdAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) => FeedbackItem(
        id: json['id'] as String,
        username: json['username'] as String,
        category: json['category'] as String,
        message: json['message'] as String,
        status: json['status'] as String? ?? 'nuevo',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class SyncSummary {
  final int sets;
  final int cards;
  final int printings;
  final int newCards;

  const SyncSummary({
    required this.sets,
    required this.cards,
    required this.printings,
    required this.newCards,
  });

  factory SyncSummary.fromJson(Map<String, dynamic> json) => SyncSummary(
        sets: json['sets'] as int,
        cards: json['cards'] as int,
        printings: json['printings'] as int,
        newCards: json['new_cards'] as int,
      );
}

/// Estado de GET /admin/sync-cards: idle | running | ok | error.
class SyncStatus {
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final SyncSummary? summary;
  final String? error;

  const SyncStatus({
    required this.status,
    this.startedAt,
    this.finishedAt,
    this.summary,
    this.error,
  });

  bool get isRunning => status == 'running';

  factory SyncStatus.fromJson(Map<String, dynamic> json) => SyncStatus(
        status: json['status'] as String,
        startedAt: json['started_at'] == null
            ? null
            : DateTime.parse(json['started_at'] as String),
        finishedAt: json['finished_at'] == null
            ? null
            : DateTime.parse(json['finished_at'] as String),
        summary: json['summary'] == null
            ? null
            : SyncSummary.fromJson(json['summary'] as Map<String, dynamic>),
        error: json['error'] as String?,
      );
}
