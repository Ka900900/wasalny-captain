import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:waslny_captain/core/services/document_upload_service.dart';

/// أنواع الصور المدعومة للرفع.
enum UploadType { profile, license, idCard, car, insurance }

/// Legacy upload service.
///
/// Maps old [UploadType] values to the new [DocumentUploadService] endpoints.
/// All existing callers continue to work unchanged.
class ImageUploadService {
  ImageUploadService._();
  static final ImageUploadService instance = ImageUploadService._();

  /// Map old [UploadType] → new [UploadDocType].
  static final Map<UploadType, UploadDocType> _typeMap = {
    UploadType.profile: UploadDocType.profile,
    UploadType.license: UploadDocType.license,
    UploadType.idCard: UploadDocType.idFront,
    UploadType.car: UploadDocType.car,
    UploadType.insurance: UploadDocType.insurance,
  };

  /// يرفع [file] إلى الـ Backend ويُرجع الرابط الآمن (imageUrl).
  ///
  /// يُرجع `imageUrl` عند النجاح، أو `null` عند أي فشل.
  Future<String?> uploadImage({
    required UploadType type,
    required File file,
  }) async {
    final docType = _typeMap[type];
    if (docType == null) {
      debugPrint('[ImageUpload] ❌ Unknown UploadType: $type');
      return null;
    }

    try {
      final result = await DocumentUploadService.instance
          .uploadImage(docType: docType, file: file)
          .first;

      if (result.success) return result.imageUrl;

      debugPrint('[ImageUpload] ❌ ${result.error}');
      return null;
    } catch (e, stack) {
      debugPrint('[ImageUpload] ❌ خطأ غير متوقع: $e');
      debugPrint('[ImageUpload]   $stack');
      return null;
    }
  }
}
