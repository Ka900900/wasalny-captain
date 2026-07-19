/// A single passenger rating left for the captain.
class Rating {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String fromUserName;
  final String rideRoute;

  const Rating({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.fromUserName,
    required this.rideRoute,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      fromUserName: json['fromUserName'] as String? ?? 'راكب',
      rideRoute: json['rideRoute'] as String? ?? '',
    );
  }
}
