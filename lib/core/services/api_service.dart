// ignore_for_file: use_null_aware_elements

import 'dart:convert';
import 'package:http/http.dart' as http;

/// HTTP API client for communicating with the Waslny Backend API.
///
/// Handles authentication via JWT token stored in memory.
/// In production, use [shared_preferences] or [flutter_secure_storage]
/// for persistent token storage across app restarts.
class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  // Change this to your production URL when deploying
  static const String _baseUrl = 'http://192.168.1.10:3000/api/v1';

  String? _token;

  // ── Token Management ─────────────────────────────────

  void saveToken(String token) {
    _token = token;
  }

  String? getToken() => _token;

  void clearToken() {
    _token = null;
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  // ── HTTP Helpers ─────────────────────────────────────

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      message: body['error'] as String? ?? 'خطأ في الاتصال بالسيرفر',
      statusCode: response.statusCode,
    );
  }

  // ── Auth Endpoints ───────────────────────────────────

  /// Sign in / register via Firebase ID Token.
  ///
  /// Sends the Firebase ID Token (obtained after successful phone OTP
  /// verification) to the backend. The backend verifies the token with
  /// Firebase Admin SDK, looks up / creates the user in PostgreSQL, and
  /// returns the application's own JWT.
  Future<Map<String, dynamic>> signInWithFirebase(
    String firebaseIdToken,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/firebase'),
      headers: _headers(auth: false),
      body: jsonEncode({'idToken': firebaseIdToken}),
    );
    final result = await _handleResponse(response);
    if (result['token'] != null) {
      saveToken(result['token'] as String);
    }
    return result;
  }

  /// Send OTP to phone number
  Future<Map<String, dynamic>> sendOtp(
    String phoneNumber, {
    String? firstName,
    String? lastName,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/send-otp'),
      headers: _headers(auth: false),
      body: jsonEncode({
        'phoneNumber': phoneNumber,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
      }),
    );
    return _handleResponse(response);
  }

  /// Verify OTP and get JWT token
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/verify-otp'),
      headers: _headers(auth: false),
      body: jsonEncode({'phoneNumber': phoneNumber, 'otp': otp}),
    );
    final result = await _handleResponse(response);
    if (result['token'] != null) {
      saveToken(result['token'] as String);
    }
    return result;
  }

  /// Register as a driver
  Future<Map<String, dynamic>> registerDriver({
    required String carModel,
    required String carPlateNumber,
    required String carColor,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register-driver'),
      headers: _headers(),
      body: jsonEncode({
        'carModel': carModel,
        'carPlateNumber': carPlateNumber,
        'carColor': carColor,
      }),
    );
    final result = await _handleResponse(response);
    if (result['token'] != null) {
      saveToken(result['token'] as String);
    }
    return result;
  }

  // ── Wallet Endpoints ─────────────────────────────────

  /// Get wallet balance
  Future<Map<String, dynamic>> getWalletBalance() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/wallet/balance'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Get wallet transactions
  Future<Map<String, dynamic>> getWalletTransactions() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/wallet/transactions'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Request a withdrawal
  Future<Map<String, dynamic>> requestWithdraw({
    required double amount,
    required String bankName,
    required String bankAccount,
    required String accountHolder,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/wallet/withdraw'),
      headers: _headers(),
      body: jsonEncode({
        'amount': amount,
        'bankName': bankName,
        'bankAccount': bankAccount,
        'accountHolder': accountHolder,
      }),
    );
    return _handleResponse(response);
  }

  /// Get withdrawal history
  Future<Map<String, dynamic>> getWithdrawals() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/wallet/withdraws'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  // ── Driver Endpoints ─────────────────────────────────

  /// Update driver location
  Future<Map<String, dynamic>> updateLocation(double lat, double lng) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/driver/location'),
      headers: _headers(),
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    return _handleResponse(response);
  }

  /// Get available rides nearby
  Future<Map<String, dynamic>> getAvailableRides() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/driver/available-rides'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Accept a ride
  Future<Map<String, dynamic>> acceptRide(String rideId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/driver/accept-ride/$rideId'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Start a ride
  Future<Map<String, dynamic>> startRide(String rideId) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/driver/ride/start/$rideId'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Complete a ride
  Future<Map<String, dynamic>> completeRide(String rideId) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/driver/ride/complete/$rideId'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Get earnings summary
  Future<Map<String, dynamic>> getEarnings() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/driver/earnings'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  // ── User Endpoints ───────────────────────────────────

  /// Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/profile'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? avatarUrl,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/user/profile/update'),
      headers: _headers(),
      body: jsonEncode({
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      }),
    );
    return _handleResponse(response);
  }

  /// Rate a user
  Future<Map<String, dynamic>> rateUser({
    required String rideId,
    required String toUserId,
    required int rating,
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/rate'),
      headers: _headers(),
      body: jsonEncode({
        'rideId': rideId,
        'toUserId': toUserId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      }),
    );
    return _handleResponse(response);
  }
}

/// Exception thrown when an API request fails.
class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException({required this.message, required this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
