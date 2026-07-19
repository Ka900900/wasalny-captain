import 'package:waslny_captain/core/models/rating.dart';
import 'package:waslny_captain/core/services/api_service.dart';

/// Result bundle returned by [RatingsRepository.fetchRatings].
class RatingsResult {
  final double averageRating;
  final int totalRatings;
  final List<Rating> ratings;

  const RatingsResult({
    this.averageRating = 0,
    this.totalRatings = 0,
    this.ratings = const [],
  });
}

/// Repository that fetches the captain's ratings from the Waslny Backend API.
///
/// Calls `GET /api/v1/driver/ratings`. If the request fails (no connectivity,
/// expired token, server error) the underlying [ApiException] is rethrown so
/// the UI can show a proper error message. The only case that returns an empty
/// result is when the backend is intentionally disabled (`backendEnabled =
/// false`) — not a connection failure. There is no fallback to sample/fake
/// data, matching the wallet & earnings repositories.
class RatingsRepository {
  RatingsRepository._();
  static final RatingsRepository instance = RatingsRepository._();

  final ApiService _api = ApiService.instance;

  Future<RatingsResult> fetchRatings() async {
    final result = await _api.getDriverRatings();

    // Support both a direct payload and a `data` envelope.
    final payload = result['data'] as Map<String, dynamic>? ?? result;

    final ratingsRaw = payload['ratings'];
    final List<Rating> ratings = [];
    if (ratingsRaw is List) {
      for (final raw in ratingsRaw) {
        if (raw is! Map<String, dynamic>) continue;
        ratings.add(Rating.fromJson(raw));
      }
    }

    return RatingsResult(
      averageRating: (payload['averageRating'] as num?)?.toDouble() ?? 0,
      totalRatings: (payload['totalRatings'] as num?)?.toInt() ?? 0,
      ratings: ratings,
    );
  }
}
