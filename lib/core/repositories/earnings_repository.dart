import 'package:http/http.dart' as http;

import 'package:waslny_captain/core/models/earnings_data.dart';
import 'package:waslny_captain/core/services/api_service.dart';

/// Repository that fetches earnings data from the Waslny Backend API.
///
/// Every method calls `GET /api/v1/driver/earnings?period=<daily|weekly|monthly>`
/// and converts the JSON response into [EarningsData].
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

  /// Daily view – `period=daily`.
  Future<EarningsData> fetchDaily() => _fetch(period: 'daily');

  /// Weekly view – `period=weekly`.
  Future<EarningsData> fetchWeekly() => _fetch(period: 'weekly');

  /// Monthly view – `period=monthly`.
  Future<EarningsData> fetchMonthly() => _fetch(period: 'monthly');

  // ──────────────────────────────────────────────────────
  // Backend call + mapping
  // ──────────────────────────────────────────────────────

  Future<EarningsData> _fetch({required String period}) async {
    try {
      final result = await _api.getEarnings(period: period);

      // The backend may return the payload directly or wrapped in a `data`
      // envelope – support both shapes.
      final payload = result['data'] as Map<String, dynamic>? ?? result;

      final periodsRaw = payload['periods'];
      final List<EarningsPeriod> periods = [];
      if (periodsRaw is List) {
        for (final raw in periodsRaw) {
          if (raw is! Map<String, dynamic>) continue;
          periods.add(
            EarningsPeriod(
              label: raw['label'] as String? ?? '',
              amount: (raw['amount'] as num?)?.toDouble() ?? 0,
              tripCount: (raw['tripCount'] as num?)?.toInt() ?? 0,
              distanceKm: (raw['distanceKm'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }

      return EarningsData(
        totalAmount: (payload['totalAmount'] as num?)?.toDouble() ?? 0,
        totalTrips: (payload['totalTrips'] as num?)?.toInt() ?? 0,
        totalDistanceKm: (payload['totalDistanceKm'] as num?)?.toDouble() ?? 0,
        averagePerTrip: (payload['averagePerTrip'] as num?)?.toDouble() ?? 0,
        periods: periods,
      );
    } on ApiException catch (e) {
      throw _toEarningsException(e);
    } on http.ClientException {
      throw const EarningsException(
        'لا يوجد اتصال بالإنترنت، تحقق من شبكتك وحاول مجدداً',
      );
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
