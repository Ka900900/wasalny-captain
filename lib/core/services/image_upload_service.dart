import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:waslny_captain/core/services/api_service.dart';

/// خدمة رفع الصور إلى الـ Backend (Railway) عبر multipart/form-data.
///
/// لم يعد Flutter يتعامل مع Cloudinary مباشرةً. بدلاً من ذلك يُرسل
/// الملف إلى الـ Backend المحمي بـ JWT، والذي يقوم بدوره برفع الصورة
/// إلى Cloudinary (عبر Multer + Cloudinary SDK) وحفظ الرابط في قاعدة
/// البيانات (Prisma/PostgreSQL)، ثم يُرجع الرابط الآمن في الاستجابة.
class ImageUploadService {
  ImageUploadService._();
  static final ImageUploadService instance = ImageUploadService._();

  /// أنواع الصور المدعومة (تطابق الـ Endpoints في الـ Backend).
  static const Map<UploadType, String> _endpoints = {
    UploadType.profile: 'profile',
    UploadType.license: 'license',
    UploadType.idCard: 'id-card',
    UploadType.car: 'car',
    UploadType.insurance: 'insurance',
  };

  /// يرفع [file] إلى الـ Backend ويُرجع الرابط الآمن (imageUrl).
  ///
  /// [type]      : نوع الصورة (يحدد الـ Endpoint).
  /// [file]      : الملف المحلي المراد رفعه.
  ///
  /// يُرجع `imageUrl` عند النجاح، أو `null` عند أي فشل
  /// (شبكة/401/500/استجابة غير صالحة) دون إغلاق التطبيق.
  Future<String?> uploadImage({
    required UploadType type,
    required File file,
  }) async {
    try {
      // التأكد من توفر توكن JWT في الذاكرة (يُستعاد من التخزين عند الحاجة).
      await ApiService.instance.ensureTokenReady();

      final token = ApiService.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[ImageUpload] ❌ لا يوجد JWT — يجب تسجيل الدخول أولاً');
        return null;
      }

      final path = _endpoints[type]!;
      final uri = Uri.parse('${ApiService.baseUrl}/upload/$path');

      debugPrint('[ImageUpload] ▶ رفع الصورة — النوع: $type');
      debugPrint('[ImageUpload]   الملف: ${file.path}');
      debugPrint('[ImageUpload]   Endpoint: $uri');

      // بناء طلب multipart/form-data مع ترويسة Authorization Bearer.
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('image', file.path));

      // ── DEBUG: اطبع الرابط قبل الإرسال ──
      print(request.url);

      final streamed = await request.send();

      // ── DEBUG: اطبع Status Code + Raw Body ──
      print("Status Code: ${streamed.statusCode}");

      final body = await streamed.stream.bytesToString();
      print("Response Body: $body");

      final response = http.Response(body, streamed.statusCode);

      debugPrint('[ImageUpload]   HTTP Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final imageUrl = body?['imageUrl'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          debugPrint('[ImageUpload] ✅ نجح الرفع — imageUrl: $imageUrl');
          return imageUrl;
        }
        debugPrint('[ImageUpload] ⚠ الاستجابة بدون imageUrl');
        return null;
      }

      debugPrint('[ImageUpload] ❌ فشل الرفع — الجسم: ${response.body}');
      return null;
    } catch (e, stack) {
      debugPrint('[ImageUpload] ❌ خطأ غير متوقع أثناء الرفع: $e');
      debugPrint('[ImageUpload]   $stack');
      return null;
    }
  }
}

/// أنواع الصور المدعومة للرفع.
enum UploadType { profile, license, idCard, car, insurance }
