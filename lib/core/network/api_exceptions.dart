/// Centralised API exception handling for the Waslny Captain app.
///
/// Provides [ApiException] (backward‑compatible with the original
/// `api_service.dart` class) plus a factory that maps low‑level
/// [DioException] values into user‑friendly Arabic messages.
///
/// Usage:
/// ```dart
/// try {
///   await dio.post(...);
/// } on ApiException catch (e) {
///   showSnackBar(e.message);
/// }
/// ```

import 'package:dio/dio.dart';

// ═════════════════════════════════════════════════════════════════════════════
// ApiException
// ═════════════════════════════════════════════════════════════════════════════

/// Exception thrown when an API request fails.
///
/// Kept backward‑compatible with the original [ApiException] in
/// `api_service.dart` so existing catch blocks continue to work.
class ApiException implements Exception {
  /// User‑facing error message (Arabic).
  final String message;

  /// HTTP status code, or `-1` for non‑HTTP errors.
  final int statusCode;

  /// Optional backend error code (e.g. `"TOKEN_EXPIRED"`).
  final String? errorCode;

  const ApiException({
    required this.message,
    this.statusCode = -1,
    this.errorCode,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';

  // ── Factory from DioException ──────────────────────────────────

  /// Creates an [ApiException] from a [DioException] by inspecting its
  /// type and response status code.
  factory ApiException.fromDioException(DioException e) {
    // ── Timeout ──────────────────────────────────────────────────
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const ApiException(
        message: 'انتهت مهلة الاتصال. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.',
        statusCode: -1,
        errorCode: 'TIMEOUT',
      );
    }

    // ── No internet / connection refused ─────────────────────────
    if (e.type == DioExceptionType.connectionError) {
      return const ApiException(
        message: 'تعذر الاتصال بالخادم. تأكد من اتصالك بالإنترنت.',
        statusCode: -1,
        errorCode: 'CONNECTION_ERROR',
      );
    }

    // ── Canceled ─────────────────────────────────────────────────
    if (e.type == DioExceptionType.cancel) {
      return const ApiException(
        message: 'تم إلغاء الطلب.',
        statusCode: -1,
        errorCode: 'CANCELLED',
      );
    }

    // ── Response errors (4xx, 5xx) ───────────────────────────────
    final response = e.response;
    if (response != null) {
      final statusCode = response.statusCode ?? -1;
      final body = response.data;

      // Try to extract a backend‑provided error message.
      String? backendMessage;
      if (body is Map<String, dynamic>) {
        backendMessage = body['error'] as String? ??
            body['message'] as String?;
      }

      switch (statusCode) {
        case 400:
          return ApiException(
            message: backendMessage ?? 'طلب غير صالح. يرجى التحقق من البيانات.',
            statusCode: statusCode,
            errorCode: 'BAD_REQUEST',
          );
        case 401:
          return ApiException(
            message: backendMessage ??
                'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى.',
            statusCode: statusCode,
            errorCode: 'UNAUTHORIZED',
          );
        case 403:
          return ApiException(
            message: backendMessage ??
                'ليس لديك صلاحية للوصول إلى هذه الخدمة.',
            statusCode: statusCode,
            errorCode: 'FORBIDDEN',
          );
        case 404:
          return ApiException(
            message: backendMessage ?? 'الخدمة المطلوبة غير موجودة.',
            statusCode: statusCode,
            errorCode: 'NOT_FOUND',
          );
        case 409:
          return ApiException(
            message: backendMessage ?? 'حدث تعارض في البيانات. حاول مرة أخرى.',
            statusCode: statusCode,
            errorCode: 'CONFLICT',
          );
        case 413:
          return ApiException(
            message: 'حجم الملف كبير جداً. يرجى اختيار ملف أصغر.',
            statusCode: statusCode,
            errorCode: 'PAYLOAD_TOO_LARGE',
          );
        case 422:
          return ApiException(
            message: backendMessage ?? 'بيانات غير صالحة. يرجى التحقق من المدخلات.',
            statusCode: statusCode,
            errorCode: 'UNPROCESSABLE_ENTITY',
          );
        case 429:
          return const ApiException(
            message: 'طلبات كثيرة جداً. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.',
            statusCode: 429,
            errorCode: 'RATE_LIMITED',
          );
        case 500:
          return ApiException(
            message: backendMessage ?? 'خطأ داخلي في الخادم. حاول مرة أخرى لاحقاً.',
            statusCode: statusCode,
            errorCode: 'SERVER_ERROR',
          );
        case 502:
        case 503:
          return ApiException(
            message: 'الخادم غير متاح حالياً. يرجى المحاولة لاحقاً.',
            statusCode: statusCode,
            errorCode: 'SERVICE_UNAVAILABLE',
          );
        default:
          return ApiException(
            message: backendMessage ?? 'حدث خطأ غير متوقع. حاول مرة أخرى.',
            statusCode: statusCode,
            errorCode: 'UNKNOWN',
          );
      }
    }

    // ── Fallback ─────────────────────────────────────────────────
    return ApiException(
      message: 'حدث خطأ غير متوقع: ${e.message ?? "غير معروف"}',
      statusCode: -1,
      errorCode: 'UNKNOWN',
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// NetworkException (optional rich hierarchy for callers who want it)
// ═════════════════════════════════════════════════════════════════════════════

/// Sealed hierarchy of network‑related exceptions for finer‑grained handling.
///
/// Every variant exposes a [message] property and can be converted back to
/// a generic [ApiException] via [toApiException].
sealed class NetworkException implements Exception {
  String get message;

  ApiException toApiException();
}

/// No internet connection.
class NoInternetException extends NetworkException {
  @override
  final String message;
  NoInternetException({this.message = 'لا يوجد اتصال بالإنترنت.'});

  @override
  ApiException toApiException() => const ApiException(
        message: 'لا يوجد اتصال بالإنترنت.',
        statusCode: -1,
        errorCode: 'NO_INTERNET',
      );
}

/// Request timed out.
class TimeoutException extends NetworkException {
  @override
  final String message;
  TimeoutException({this.message = 'انتهت مهلة الاتصال. حاول مرة أخرى.'});

  @override
  ApiException toApiException() => const ApiException(
        message: 'انتهت مهلة الاتصال. حاول مرة أخرى.',
        statusCode: -1,
        errorCode: 'TIMEOUT',
      );
}

/// Server returned an HTTP error.
class ServerException extends NetworkException {
  @override
  final String message;
  final int statusCode;
  ServerException({required this.message, required this.statusCode});

  @override
  ApiException toApiException() => ApiException(
        message: message,
        statusCode: statusCode,
      );
}

/// Unexpected / unknown error.
class UnknownNetworkException extends NetworkException {
  @override
  final String message;
  final Object? cause;
  UnknownNetworkException({this.message = 'حدث خطأ غير متوقع.', this.cause});

  @override
  ApiException toApiException() => ApiException(message: message);
}
