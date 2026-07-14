// Pagination primitives shared across all paginated endpoints.

/// Parsed response from a cursor-paginated API endpoint.
///
/// The backend returns `{"data": [...], "next_cursor": "..."}`.
/// [nextCursor] is `null` when there are no more results.
class PaginatedList<T> {
  final List<T> data;
  final String? nextCursor;

  const PaginatedList({required this.data, this.nextCursor});

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory PaginatedList.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final cursor = json['next_cursor'] as String?;
    return PaginatedList(
      data: (json['data'] as List<dynamic>)
          .map((j) => fromJson(j as Map<String, dynamic>))
          .toList(),
      nextCursor: (cursor != null && cursor.isNotEmpty) ? cursor : null,
    );
  }
}

/// UI state for an infinite-scroll list backed by cursor pagination.
class PaginatedState<T> {
  final List<T> items;
  final String? nextCursor;
  final bool isLoadingMore;

  const PaginatedState({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  PaginatedState<T> copyWith({
    List<T>? items,
    String? nextCursor,
    bool? isLoadingMore,
  }) =>
      PaginatedState(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}
