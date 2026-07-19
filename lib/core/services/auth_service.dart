import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/services/notification_service.dart';

/// Service responsible for all Firebase Authentication operations.
///
/// Wraps [FirebaseAuth] to provide a clean API for driver authentication
/// (Google Sign-In), session management, and logout.
class AuthService {
  /// Singleton pattern — use [AuthService.instance] everywhere.
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _backendBaseUrl =
      'https://wasalny-backend-production.up.railway.app/api/v1';

  // ──────────────────────────────────────────────
  // Streams
  // ──────────────────────────────────────────────

  /// A broadcast stream that emits the current [User] (or `null`) whenever the
  /// authentication state changes (sign-in, sign-out, token refresh).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ──────────────────────────────────────────────
  // Queries
  // ──────────────────────────────────────────────

  /// Returns `true` when a user is currently signed in.
  bool get isLoggedIn => _auth.currentUser != null;

  /// Returns the currently signed-in user, or `null`.
  User? get currentUser => _auth.currentUser;

  /// Phone number of the currently signed-in user, or an empty string.
  String get currentPhoneNumber => currentUser?.phoneNumber ?? '';

  // ──────────────────────────────────────────────
  // Phone Authentication
  // ──────────────────────────────────────────────

  /// Starts phone-number verification for production Firebase Auth.
  Future<void> verifyPhoneNumber(
    String phone,
    void Function(String verificationId) onCodeSent,
    void Function(String error) onError,
  ) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            onError(_mapFirebaseError(e));
          }
        },
        verificationFailed: (FirebaseAuthException exception) {
          print("❌ verificationFailed");
          print("Code: ${exception.code}");
          print("Message: ${exception.message}");
          onError(_mapFirebaseError(exception));
        },
        codeSent: (String verificationId, int? resendToken) {
          print("✅ codeSent");
          print("Verification ID: $verificationId");
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onError('انتهت مهلة استرجاع الرمز تلقائيًا.');
        },
        timeout: const Duration(seconds: 60),
      );
    } on FirebaseAuthException catch (exception) {
      onError(_mapFirebaseError(exception));
    } catch (exception) {
      onError(exception.toString());
    }
  }

  /// Verifies the SMS code and signs in with Firebase.
  /// Returns the Firebase ID token on success.
  Future<String> verifyOTP(String verificationId, String smsCode) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'لم يتم إنشاء حساب Firebase بعد التحقق.',
        );
      }

      final firebaseToken = await user.getIdToken(true);
      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'token-error',
          message: 'فشل في استخراج Firebase ID Token.',
        );
      }

      return firebaseToken;
    } on FirebaseAuthException catch (exception) {
      throw FirebaseAuthException(
        code: exception.code,
        message: _mapFirebaseError(exception),
      );
    } catch (exception) {
      throw Exception('فشل التحقق من الرمز: $exception');
    }
  }

  /// Signs in with a phone credential produced by automatic verification.
  Future<UserCredential> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    final result = await _auth.signInWithCredential(credential);
    await result.user!.getIdToken(true);
    return result;
  }

  /// Returns the current Firebase ID Token.
  /// Throws if there is no signed-in user.
  Future<String> getIdToken({bool forceRefresh = true}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'No authenticated user found.',
      );
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null) {
      throw FirebaseAuthException(
        code: 'no-token',
        message: 'Failed to retrieve the ID token.',
      );
    }
    return token;
  }

  // ──────────────────────────────────────────────
  // Google Sign-In
  // ──────────────────────────────────────────────

  /// Signs in with Google, exchanges the credential with Firebase, obtains
  /// the Firebase ID Token, then sends it to the backend for the app JWT.
  ///
  /// Returns the backend response map (contains the app JWT).
  /// Throws on any failure.
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // 1. Trigger Google Sign-In flow
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'تم إلغاء تسجيل الدخول بواسطة جوجل.',
        );
      }

      // 2. Obtain Google authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'no-id-token',
          message: 'فشل في الحصول على معرف Google ID Token.',
        );
      }

      // 3. Create Firebase credential and sign in
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'لم يتم إنشاء حساب Firebase بعد التحقق من جوجل.',
        );
      }

      // 4. Get the Firebase ID Token
      final firebaseToken = await user.getIdToken(true);
      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'token-error',
          message: 'فشل في استخراج Firebase ID Token.',
        );
      }

      // 5. Exchange Firebase Token → Backend JWT
      final jwt = await loginWithBackend(firebaseToken);

      return {
        'token': jwt,
        'firebaseToken': firebaseToken,
        'message': 'تم تسجيل الدخول بنجاح',
      };
    } on FirebaseAuthException {
      rethrow;
    } catch (exception) {
      throw Exception('فشل تسجيل الدخول بحساب جوجل: $exception');
    }
  }

  /// Disconnects the Google Sign-In session (useful for switching accounts).
  Future<void> disconnectGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.disconnect();
    }
  }

  // ──────────────────────────────────────────────
  // App JWT (Exchange Firebase Token → Backend JWT)
  // ──────────────────────────────────────────────

  /// Sends the current Firebase ID Token to the Node.js backend and returns
  /// the application's own JWT.
  ///
  /// The backend verifies the Firebase token via Firebase Admin SDK, then
  /// creates or updates the driver in PostgreSQL and issues a custom JWT.
  ///
  /// The JWT is automatically saved in [ApiService] and used for all
  /// subsequent API requests.
  Future<Map<String, dynamic>> exchangeFirebaseTokenForAppJWT() async {
    final firebaseToken = await getIdToken(forceRefresh: true);
    final jwt = await loginWithBackend(firebaseToken);
    return {'token': jwt, 'message': 'تم تسجيل الدخول بنجاح'};
  }

  /// Exchanges the Firebase ID Token with the Node.js backend and returns the
  /// app JWT used by the backend APIs.
  Future<String> loginWithBackend(String firebaseToken) async {
    // Backend disabled → run on Firebase only (no custom JWT exchange).
    if (!ApiService.backendEnabled) return '';
    try {
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/auth/firebase-login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'firebaseIdToken': firebaseToken}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // DEBUG: اطبع رسالة الخطأ الكاملة من السيرفر قبل الرمي
        print('[loginWithBackend] body[error] = ${body['error']}');
        print('[loginWithBackend] full body = $body');
        throw ApiException(
          message: body['error'] as String? ?? 'فشل تسجيل الدخول مع الخادم',
          statusCode: response.statusCode,
        );
      }

      final jwt = body['token'] as String?;
      if (jwt == null || jwt.isEmpty) {
        throw ApiException(
          message: 'لم يتم استلام JWT من الخادم',
          statusCode: response.statusCode,
        );
      }

      ApiService.instance.saveToken(jwt);
      // TODO(temp-debug): remove after grabbing the JWT for manual endpoint testing
      print('=== JWT TOKEN: ${ApiService.instance.getToken()} ===');

      // Register the FCM token with the backend so the server can send this
      // captain real ride-alert push notifications. Fire-and-forget: failures
      // are logged inside the service and must not break the login flow.
      unawaited(NotificationService.instance.registerTokenWithBackend());

      return jwt;
    } on ApiException {
      rethrow;
    } catch (exception) {
      throw Exception('فشل الاتصال بالخادم: $exception');
    }
  }

  // ──────────────────────────────────────────────
  // Sign Out
  // ──────────────────────────────────────────────

  /// Signs out the current driver and clears the stored app JWT.
  Future<void> signOut() async {
    ApiService.instance.clearToken();
    await _auth.signOut();
  }

  String _mapFirebaseError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-verification-code':
          return 'رمز التحقق غير صحيح. حاول مرة أخرى.';
        case 'session-expired':
          return 'انتهت صلاحية الجلسة. أعد إرسال الرمز.';
        case 'too-many-requests':
          return 'تم تجاوز عدد المحاولات المسموح بها. حاول لاحقًا.';
        case 'network-request-failed':
          return 'تحقق من اتصال الإنترنت ثم أعد المحاولة.';
        default:
          return error.message ?? 'فشل التحقق من الهوية.';
      }
    }

    return error.toString();
  }
}
