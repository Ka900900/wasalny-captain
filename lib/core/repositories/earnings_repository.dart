import 'package:waslny_captain/core/network/api_exceptions.dart';
import 'package:waslny_captain/core/models/earnings_data.dart';
import 'package:waslny_captain/core/services/api_service.dart';

/// Repository that fetches earnings data from the Waslny Backend API.
///
/// Backend endpoint: `GET /api/v1/captain/earnings?period=daily|weekly|monthly`
///
/// There is **no fallback to sample/fake data**. If the API returns an error
/// (expired token, server error, or no connectivity) a clear [EarningsException]
/// is thrown so the UI can show a meaningful Arabic message to the captain.
class EarningsRepository {
  EarningsRepository._();
  static final EarningsRepository instance = EarningsRepository._();

  final ApiService _api = ApiService.instance;

  // ──────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────

  /// Daily view – rides from today.
  Future<EarningsData> fetchDaily() => _fetch(period: 'daily');

  /// Weekly view – rides from this week (Monday–today).
  Future<EarningsData> fetchWeekly() => _fetch(period: 'weekly');

  /// Monthly view – rides from this month.
  Future<EarningsData> fetchMonthly() => _fetch(period: 'monthly');

  // ──────────────────────────────────────────────────────
  // جلب الأرباح من الباك إند
  // ──────────────────────────────────────────────────────

  Future<EarningsData> _fetch({required String period}) async {
    try {
      final result = await _api.getEarnings(period: period);

      // Parse periods (for charts) if the backend returns them
      final List<EarningsPeriod> periods;
      if (result['periods'] != null) {
        final rawPeriods = result['periods'] as List<dynamic>;
        periods = rawPeriods.map((p) {
          final map = p as Map<String, dynamic>;
          return EarningsPeriod(
            label: map['label'] as String? ?? '',
            amount: (map['amount'] as num?)?.toDouble() ?? 0,
            tripCount: (map['tripCount'] as num?)?.toInt() ?? 0,
            distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
      } else {
        periods = const [];
      }

      return EarningsData(
        totalAmount: (result['totalAmount'] as num?)?.toDouble() ?? 0,
        totalTrips: (result['totalTrips'] as num?)?.toInt() ?? 0,
        totalDistanceKm: (result['totalDistanceKm'] as num?)?.toDouble() ?? 0,
        averagePerTrip: (result['averagePerTrip'] as num?)?.toDouble() ?? 0,
        periods: periods,
      );
    } on ApiException catch (e) {
      throw _toEarningsException(e);
    } catch (e) {
      throw EarningsException('تعذر تحميل بيانات الأرباح: ${e.toString()}');
    }
  }

  /// Maps an [ApiException] to a clear, user‑facing Arabic message.
  EarningsException _toEarningsException(ApiException e) {
    switch (e.statusCode) {
      case 401:
        return const EarningsException(
          'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً',
        );
      case 500:
      case 502:
      case 503:
        return const EarningsException(
          'حدث خطأ في الخادم، حاول مرة أخرى لاحقاً',
        );
      default:
        return EarningsException(
          e.message.isNotEmpty ? e.message : 'تعذر تحميل بيانات الأرباح',
        );
    }
  }
}

/// Exception thrown when earnings cannot be loaded from the backend.
///
/// The [message] is already localized (Arabic) and safe to display directly
/// to the user.
class EarningsException implements Exception {
  final String message;

  const EarningsException(this.message);

  @override
  String toString() => message;
}
