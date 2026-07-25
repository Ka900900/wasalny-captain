import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  // حفظ التوكن
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  // قراءة التوكن
  static Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  // حفظ بيانات المستخدم كـ JSON
  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: 'user_data', value: jsonEncode(user));
  }

  // قراءة بيانات المستخدم
  static Future<Map<String, dynamic>?> getUser() async {
    String? userStr = await _storage.read(key: 'user_data');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  // مسح الجلسة (تسجيل الخروج)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}