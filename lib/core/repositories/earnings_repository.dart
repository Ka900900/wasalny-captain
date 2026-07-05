import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:waslny_captain/core/models/earnings_data.dart';

/// Time granularity for earnings aggregation.
enum _Granularity { day, week, month }

/// Repository that fetches and aggregates earnings data from the `rides`
/// Firestore collection.
///
/// Every method queries completed rides owned by [captainId], groups them by
/// the requested time granularity, and returns [EarningsData].  If no real
/// data exists a set of realistic sample data is returned so the UI is never
/// empty during development.
class EarningsRepository {
  EarningsRepository._();
  static final EarningsRepository instance = EarningsRepository._();

  // ──────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────

  /// Daily view – groups completed rides by **day of the current week**.
  Future<EarningsData> fetchDaily({required String captainId}) async {
    final range = _currentWeekRange();
    final docs = await _fetchCompletedRides(captainId, range.$1, range.$2);

    if (docs.isEmpty) return _sampleDaily();

    return _aggregate(docs, _Granularity.day);
  }

  /// Weekly view – groups completed rides by **week of the current month**.
  Future<EarningsData> fetchWeekly({required String captainId}) async {
    final range = _currentMonthRange();
    final docs = await _fetchCompletedRides(captainId, range.$1, range.$2);

    if (docs.isEmpty) return _sampleWeekly();

    return _aggregate(docs, _Granularity.week);
  }

  /// Monthly view – groups completed rides by **month of the current year**.
  Future<EarningsData> fetchMonthly({required String captainId}) async {
    final range = _currentYearRange();
    final docs = await _fetchCompletedRides(captainId, range.$1, range.$2);

    if (docs.isEmpty) return _sampleMonthly();

    return _aggregate(docs, _Granularity.month);
  }

  // ──────────────────────────────────────────────────────
  // Firestore helpers
  // ──────────────────────────────────────────────────────

  Future<List<DocumentSnapshot>> _fetchCompletedRides(
    String captainId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rides')
          .where('captainId', isEqualTo: captainId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('completedAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('completedAt', descending: false)
          .get();
      return snap.docs;
    } catch (_) {
      return [];
    }
  }

  static double _parsePrice(DocumentSnapshot doc) {
    final raw = doc['price'];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0;
    return 0;
  }

  static double _parseDistance(DocumentSnapshot doc) {
    // Attempt to read a stored distance field
    final raw = doc['distance'];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0;

    // Fallback: calculate from pickupLocation <> destinationLocation
    final pickup = doc['pickupLocation'] as GeoPoint?;
    final dest = doc['destinationLocation'] as GeoPoint?;
    if (pickup != null && dest != null) {
      // Approximate using Geolocator formula
      return _haversineDistance(
        pickup.latitude, pickup.longitude,
        dest.latitude, dest.longitude,
      );
    }
    return 0;
  }

  /// Haversine formula – returns distance in kilometres.
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth radius
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double deg) => deg * pi / 180;

  // ──────────────────────────────────────────────────────
  // Aggregation
  // ──────────────────────────────────────────────────────

  EarningsData _aggregate(List<DocumentSnapshot> docs, _Granularity g) {
    // Build buckets keyed by the group index (0‑based)
    final Map<int, List<DocumentSnapshot>> buckets = {};
    for (final doc in docs) {
      final ts = doc['completedAt'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate();
      final idx = _groupIndex(dt, g);
      buckets.putIfAbsent(idx, () => []).add(doc);
    }

    final labels = _labels(g);
    final List<EarningsPeriod> periods = [];
    double totalAmount = 0;
    int totalTrips = 0;
    double totalDistance = 0;

    for (int i = 0; i < labels.length; i++) {
      final bucket = buckets[i] ?? [];
      final amount = bucket.fold<double>(0, (s, d) => s + _parsePrice(d));
      final trips = bucket.length;
      final dist = bucket.fold<double>(0, (s, d) => s + _parseDistance(d));
      periods.add(EarningsPeriod(
        label: labels[i],
        amount: amount,
        tripCount: trips,
        distanceKm: dist,
      ));
      totalAmount += amount;
      totalTrips += trips;
      totalDistance += dist;
    }

    return EarningsData(
      totalAmount: totalAmount,
      totalTrips: totalTrips,
      totalDistanceKm: totalDistance,
      averagePerTrip: totalTrips > 0 ? totalAmount / totalTrips : 0,
      periods: periods,
    );
  }

  int _groupIndex(DateTime dt, _Granularity g) {
    switch (g) {
      case _Granularity.day:
        return dt.weekday - 1;
      case _Granularity.week:
        return ((dt.day - 1) ~/ 7).clamp(0, 4);
      case _Granularity.month:
        return dt.month - 1;
    }
  }

  List<String> _labels(_Granularity g) {
    switch (g) {
      case _Granularity.day:
        return const ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      case _Granularity.week:
        return const ['الأسبوع 1', 'الأسبوع 2', 'الأسبوع 3', 'الأسبوع 4', 'الأسبوع 5'];
      case _Granularity.month:
        return const [
          'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
          'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
        ];
    }
  }

  // ──────────────────────────────────────────────────────
  // Date range helpers
  // ──────────────────────────────────────────────────────

  (DateTime, DateTime) _currentWeekRange() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Monday … 7=Sunday
    final monday = DateTime(now.year, now.month, now.day - (weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    return (monday, nextMonday);
  }

  (DateTime, DateTime) _currentMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return (start, end);
  }

  (DateTime, DateTime) _currentYearRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year + 1, 1, 1);
    return (start, end);
  }

  // ──────────────────────────────────────────────────────
  // Sample data (used when Firestore has no rides yet)
  // ──────────────────────────────────────────────────────

  EarningsData _sampleDaily() {
    return EarningsData(
      totalAmount: 1250.75,
      totalTrips: 23,
      totalDistanceKm: 420,
      averagePerTrip: 54.38,
      periods: const [
        EarningsPeriod(label: 'الاثنين', amount: 180, tripCount: 4, distanceKm: 72),
        EarningsPeriod(label: 'الثلاثاء', amount: 220, tripCount: 5, distanceKm: 88),
        EarningsPeriod(label: 'الأربعاء', amount: 150, tripCount: 3, distanceKm: 55),
        EarningsPeriod(label: 'الخميس', amount: 300, tripCount: 6, distanceKm: 105),
        EarningsPeriod(label: 'الجمعة', amount: 180, tripCount: 3, distanceKm: 60),
        EarningsPeriod(label: 'السبت', amount: 120, tripCount: 2, distanceKm: 40),
        EarningsPeriod(label: 'الأحد', amount: 100.75, tripCount: 2, distanceKm: 35),
      ],
    );
  }

  EarningsData _sampleWeekly() {
    return EarningsData(
      totalAmount: 4850.00,
      totalTrips: 92,
      totalDistanceKm: 1680,
      averagePerTrip: 52.72,
      periods: const [
        EarningsPeriod(label: 'الأسبوع 1', amount: 1100, tripCount: 20, distanceKm: 380),
        EarningsPeriod(label: 'الأسبوع 2', amount: 980, tripCount: 18, distanceKm: 340),
        EarningsPeriod(label: 'الأسبوع 3', amount: 1250, tripCount: 24, distanceKm: 440),
        EarningsPeriod(label: 'الأسبوع 4', amount: 1520, tripCount: 30, distanceKm: 520),
      ],
    );
  }

  EarningsData _sampleMonthly() {
    return EarningsData(
      totalAmount: 22450.00,
      totalTrips: 420,
      totalDistanceKm: 7850,
      averagePerTrip: 53.45,
      periods: const [
        EarningsPeriod(label: 'يناير', amount: 1800, tripCount: 34, distanceKm: 650),
        EarningsPeriod(label: 'فبراير', amount: 1650, tripCount: 30, distanceKm: 580),
        EarningsPeriod(label: 'مارس', amount: 2100, tripCount: 38, distanceKm: 720),
        EarningsPeriod(label: 'أبريل', amount: 1950, tripCount: 36, distanceKm: 690),
        EarningsPeriod(label: 'مايو', amount: 2200, tripCount: 42, distanceKm: 780),
        EarningsPeriod(label: 'يونيو', amount: 2500, tripCount: 48, distanceKm: 880),
        EarningsPeriod(label: 'يوليو', amount: 1800, tripCount: 34, distanceKm: 650),
        EarningsPeriod(label: 'أغسطس', amount: 1600, tripCount: 30, distanceKm: 560),
        EarningsPeriod(label: 'سبتمبر', amount: 1900, tripCount: 36, distanceKm: 670),
        EarningsPeriod(label: 'أكتوبر', amount: 2100, tripCount: 38, distanceKm: 740),
        EarningsPeriod(label: 'نوفمبر', amount: 1850, tripCount: 32, distanceKm: 620),
        EarningsPeriod(label: 'ديسمبر', amount: 900, tripCount: 16, distanceKm: 310),
      ],
    );
  }
}
