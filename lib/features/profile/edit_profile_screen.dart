import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:waslny_captain/core/design_system/design_system.dart';
import 'package:waslny_captain/core/models/driver_profile.dart';
import 'package:waslny_captain/core/repositories/driver_repository.dart';
import 'package:waslny_captain/core/services/auth_service.dart';

/// Screen for creating or editing a driver's profile.
///
/// If an existing [profile] is supplied the form is pre-populated with its
/// values; otherwise a new profile is created.
class EditProfileScreen extends StatefulWidget {
  final DriverProfile? profile;
  final dynamic
  captain; // accepts CaptainModel? (kept dynamic to avoid import cycle)

  const EditProfileScreen({super.key, this.profile, this.captain});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ── Text controllers ────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nationalIdCtrl;
  late final TextEditingController _licenseNumberCtrl;

  // ── Image URLs (either existing or freshly uploaded) ────
  String? _photoUrl;
  String? _licenseUrl;
  String? _idCardUrl;

  // ── Locally picked image bytes for preview before upload ─
  File? _pickedPhoto;
  File? _pickedLicense;
  File? _pickedIdCard;

  bool _isSaving = false;

  // ────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _nationalIdCtrl = TextEditingController(text: p?.nationalId ?? '');
    _licenseNumberCtrl = TextEditingController(text: p?.licenseNumber ?? '');
    _photoUrl = p?.photoUrl;
    _licenseUrl = p?.licenseUrl;
    _idCardUrl = p?.idCardUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nationalIdCtrl.dispose();
    _licenseNumberCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────
  // Image pickers — one per image type
  // ────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _pickedPhoto = File(picked.path);
        _photoUrl = null; // will be uploaded on save
      });
    }
  }

  Future<void> _pickLicense() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _pickedLicense = File(picked.path);
        _licenseUrl = null;
      });
    }
  }

  Future<void> _pickIdCard() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _pickedIdCard = File(picked.path);
        _idCardUrl = null;
      });
    }
  }

  /// Builds a clickable image tile (existing URL or local file).
  Widget _imageTile({
    required String label,
    required String? imageUrl,
    required File? localFile,
    required VoidCallback onPick,
  }) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
          image: localFile != null
              ? DecorationImage(image: FileImage(localFile), fit: BoxFit.cover)
              : (imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null),
        ),
        alignment: Alignment.center,
        child: (localFile == null && imageUrl == null)
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.camera_alt,
                    color: AppColors.textMuted,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppTextStyles.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // Save
  // ────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى تسجيل الدخول أولاً'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      final uid = user.uid;
      final phone = AuthService.instance.currentPhoneNumber;
      final repo = DriverRepository.instance;

      // 1. Upload any locally-picked images
      if (_pickedPhoto != null) {
        _photoUrl = await repo.uploadPickedFile(
          filePath: _pickedPhoto!.path,
          folder: 'photos',
        );
      }
      if (_pickedLicense != null) {
        _licenseUrl = await repo.uploadPickedFile(
          filePath: _pickedLicense!.path,
          folder: 'licenses',
        );
      }
      if (_pickedIdCard != null) {
        _idCardUrl = await repo.uploadPickedFile(
          filePath: _pickedIdCard!.path,
          folder: 'id_cards',
        );
      }

      // 2. Build the profile object
      final now = DateTime.now();
      final profile = DriverProfile(
        uid: uid,
        name: _nameCtrl.text.trim(),
        phone: phone,
        photoUrl: _photoUrl,
        nationalId: _nationalIdCtrl.text.trim(),
        licenseNumber: _licenseNumberCtrl.text.trim(),
        vehicleType: widget.profile?.vehicleType ?? '',
        vehicleModel: widget.profile?.vehicleModel ?? '',
        vehicleColor: widget.profile?.vehicleColor ?? '',
        vehicleNumber: widget.profile?.vehicleNumber ?? '',
        licenseUrl: _licenseUrl,
        idCardUrl: _idCardUrl,
        createdAt: widget.profile?.createdAt ?? now,
        updatedAt: now,
      );

      // 3. Persist to Firestore
      await repo.saveProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حفظ الملف الشخصي بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true); // return true = data changed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ────────────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            widget.profile == null ? 'إنشاء ملف شخصي' : 'تعديل الملف الشخصي',
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Images row ──────────────────────────
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    alignment: WrapAlignment.center,
                    children: [
                      _imageTile(
                        label: 'الصورة الشخصية',
                        imageUrl: _photoUrl,
                        localFile: _pickedPhoto,
                        onPick: _pickPhoto,
                      ),
                      _imageTile(
                        label: 'صورة البطاقة الشخصية',
                        imageUrl: _idCardUrl,
                        localFile: _pickedIdCard,
                        onPick: _pickIdCard,
                      ),
                      _imageTile(
                        label: 'صورة رخصة القيادة',
                        imageUrl: _licenseUrl,
                        localFile: _pickedLicense,
                        onPick: _pickLicense,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Name ────────────────────────────────
                  _label('الاسم الكامل'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _nameCtrl,
                    style: AppTextStyles.bodyLarge,
                    decoration: _inputDecoration('أدخل الاسم الكامل'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'هذا الحقل مطلوب'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Phone (read-only) ───────────────────
                  _label('رقم الهاتف'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    initialValue: AuthService.instance.currentPhoneNumber,
                    readOnly: true,
                    style: AppTextStyles.bodyLarge?.copyWith(
                      color: AppColors.textMuted,
                    ),
                    decoration: _inputDecoration(null),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── National ID ─────────────────────────
                  _label('الرقم القومي'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _nationalIdCtrl,
                    style: AppTextStyles.bodyLarge,
                    decoration: _inputDecoration('أدخل الرقم القومي'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'هذا الحقل مطلوب'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _label('رقم رخصة القيادة'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _licenseNumberCtrl,
                    style: AppTextStyles.bodyLarge,
                    decoration: _inputDecoration('أدخل رقم رخصة القيادة'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'هذا الحقل مطلوب'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // ── Save button ─────────────────────────
                  WaslnyButton.primary(
                    label: 'حفظ',
                    icon: Icons.check_rounded,
                    loading: _isSaving,
                    onPressed: _isSaving ? null : _save,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Reusable label ─────────────────────────────────────
  Widget _label(String text) {
    return Text(
      text,
      style: AppTextStyles.labelLarge?.copyWith(color: AppColors.textSecondary),
    );
  }

  // ── Reusable input decoration ──────────────────────────
  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium?.copyWith(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
    );
  }
}
