import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// يعرض Bottom Sheet للمستخدم ليختار مصدر الصورة:
/// - تصوير بالكاميرا ([ImageSource.camera])
/// - اختيار من المعرض ([ImageSource.gallery])
///
/// يرجع [XFile] للصورة المختارة، أو `null` إذا ألغى المستخدم الاختيار.
Future<XFile?> pickImageWithSourceSheet(BuildContext context) async {
  final ImagePicker picker = ImagePicker();

  return showModalBottomSheet<XFile?>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('تصوير بالكاميرا'),
              onTap: () async {
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                  maxWidth: 1600,
                );
                Navigator.of(ctx).pop(photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من المعرض'),
              onTap: () async {
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                  maxWidth: 1600,
                );
                Navigator.of(ctx).pop(photo);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
