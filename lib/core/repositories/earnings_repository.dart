import 'package:http/http.dart' as http;

import 'package:waslny_captain/core/network/api_exceptions.dart';
import 'package:waslny_captain/core/models/earnings_data.dart';
import 'package:waslny_captain/core/models/ride_model.dart';
import 'package:waslny_captain/core/services/api_service.dart';

/// Repository that fetches earnings data from the Waslny Backend API.
///
/// 🚧 **TEMPORARY — client-side calculation, pending backend endpoint**
/// ===================================================================
/// الأصل كان `GET /driver/earnings` لكن الـ endpoint مش موجود في الباك إند.
/// الحل الحالي يستخدم `GET /rides/history` ويحسب الأرباح client-side
/// (فلترة الرحلات المكتملة + جمع fare). هذا حل مؤقت لحين إنشاء endpoint
/// مخصص للأرباح في الباك إند (الأنسب لدقة حساب العمولة والـ aggregations).
///
/// **متى يتغير؟** بمجرد ما يتوفر endpoint `/driver/earnings` نرجع نستخدمه
/// ونمسح الكود اللي تحت.
/// ===================================================================
///
/// كل دالة تجيب سجل الرحلات من `/rides/history` وتحسب الأرباح client-side
/// من الرحلات المكتملة، لأن endpoint `/driver/earnings` مش متوفر في الباك إند.
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
  // جلب الرحلات + حساب الأرباح client-side
  // ──────────────────────────────────────────────────────

  Future<EarningsData> _fetch({required String period}) async {
    try {
      // 1. نجيب كل الرحلات المكتملة من history
      final rides = await _api.getRideHistory();
      final completedRides = rides
          .where((r) => r.status == RideStatus.completed)
          .toList();

      if (completedRides.isEmpty) {
        return const EarningsData();
      }

      // 2. نحدد بداية الفترة المطلوبة
      final now = DateTime.now();
      final DateTime rangeStart = _periodStart(period, now);
      final DateTime rangeEnd = DateTime(now.year, now.month, now.day + 1);

      // 3. نصفّي الرحلات اللي جوه الفترة
      final filteredRides = completedRides.where((r) {
        if (r.createdAt == null) return false;
        return r.createdAt!.isAfter(rangeStart) &&
            r.createdAt!.isBefore(rangeEnd);
      }).toList();

      // 4. نحسب الإجماليات
      final totalAmount = filteredRides.fold<double>(
        0,
        (sum, r) => sum + (r.fare ?? 0),
      );
      final totalTrips = filteredRides.length;
      final totalDistanceKm = filteredRides.fold<double>(
        0,
        (sum, r) => sum + _parseDistance(r.distance),
      );
      final averagePerTrip = totalTrips > 0 ? totalAmount / totalTrips : 0.0;

      // 5. نبني الفترات الفرعية (للرسوم البيانية)
      final periods = _buildPeriods(filteredRides, period);

      return EarningsData(
        totalAmount: totalAmount,
        totalTrips: totalTrips,
        totalDistanceKm: totalDistanceKm,
        averagePerTrip: averagePerTrip,
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

  /// ترجع بداية الفترة المطلوبة (اليوم/الأسبوع/الشهر).
  DateTime _periodStart(String period, DateTime now) {
    switch (period) {
      case 'daily':
        return DateTime(now.year, now.month, now.day);
      case 'weekly':
        // الاثنين = أول الأسبوع
        final daysFromMonday = now.weekday - DateTime.monday;
        final weekStart = now.subtract(Duration(days: daysFromMonday));
        return DateTime(weekStart.year, weekStart.month, weekStart.day);
      case 'monthly':
        return DateTime(now.year, now.month, 1);
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  /// تستخرج الرقم من مسافة نصية زي "3.2 كم" أو "5.0 km".
  double _parseDistance(String? distanceStr) {
    if (distanceStr == null || distanceStr.isEmpty) return 0;
    final match = RegExp(r'([\d.]+)').firstMatch(distanceStr);
    if (match == null) return 0;
    return double.tryParse(match.group(1) ?? '0') ?? 0;
  }

  /// تقسيم الرحلات إلى فترات فرعية للرسوم البيانية.
  List<EarningsPeriod> _buildPeriods(List<RideModel> rides, String period) {
    if (rides.isEmpty) return [];

    final Map<String, List<RideModel>> groups = {};
    for (final ride in rides) {
      if (ride.createdAt == null) continue;
      final key = _periodKey(ride.createdAt!, period);
      groups.putIfAbsent(key, () => []).add(ride);
    }

    return groups.entries.map((entry) {
      final groupRides = entry.value;
      final amount = groupRides.fold<double>(
        0,
        (sum, r) => sum + (r.fare ?? 0),
      );
      final tripCount = groupRides.length;
      final distanceKm = groupRides.fold<double>(
        0,
        (sum, r) => sum + _parseDistance(r.distance),
      );
      return EarningsPeriod(
        label: entry.key,
        amount: amount,
        tripCount: tripCount,
        distanceKm: distanceKm,
      );
    }).toList()..sort((a, b) => a.label.compareTo(b.label));
  }

  /// تسمية المجموعة بناءً على الفترة.
  String _periodKey(DateTime date, String period) {
    switch (period) {
      case 'daily':
        return '${date.hour.toString().padLeft(2, '0')}:00';
      case 'weekly':
        const weekDays = [
          'الاثنين',
          'الثلاثاء',
          'الأربعاء',
          'الخميس',
          'الجمعة',
          'السبت',
          'الأحد',
        ];
        return weekDays[date.weekday - 1];
      case 'monthly':
        return '${date.day} ${_monthName(date.month)}';
      default:
        return '${date.day}/${date.month}';
    }
  }

  String _monthName(int month) {
    const names = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return names[month - 1];
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
