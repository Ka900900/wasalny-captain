/// A single data point inside an [EarningsData] set (e.g. one day, one week,
/// or one month).
class EarningsPeriod {
  final String label;
  final double amount;
  final int tripCount;
  final double distanceKm;

  const EarningsPeriod({
    required this.label,
    required this.amount,
    required this.tripCount,
    required this.distanceKm,
  });
}

/// Aggregated earnings data for a given time span.
///
/// Used by the [EarningsRepository] to return API‑backed earnings data,
/// and consumed by the `EarningsScreen` to render charts & stats.
class EarningsData {
  final double totalAmount;
  final int totalTrips;
  final double totalDistanceKm;
  final double averagePerTrip;
  final List<EarningsPeriod> periods;

  const EarningsData({
    this.totalAmount = 0,
    this.totalTrips = 0,
    this.totalDistanceKm = 0,
    this.averagePerTrip = 0,
    this.periods = const [],
  });
}
