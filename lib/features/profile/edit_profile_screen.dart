import 'dart:io';

import 'package:flutter/material.dart';
import 'package:waslny_captain/widgets/image_source_picker.dart';

import 'package:waslny_captain/core/design_system/design_system.dart';
import 'package:waslny_captain/core/models/driver_profile.dart';
import 'package:waslny_captain/core/repositories/driver_repository.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/image_upload_service.dart';

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
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _nationalIdCtrl;
  late final TextEditingController _licenseNumberCtrl;

  // ── Image URLs (either existing or freshly uploaded) ────
  String? _photoUrl;
  String? _licenseUrl;
  String? _idCardUrl;
  String? _criminalRecordUrl;
  String? _drugTestUrl;

  // ── Locally picked image bytes for preview before upload ─
  File? _pickedPhoto;
  File? _pickedLicense;
  File? _pickedIdCard;
  File? _pickedCriminalRecord;
  File? _pickedDrugTest;

  bool _isSaving = false;
  bool _isUploading = false;

  // ────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _phoneCtrl = TextEditingController(
      text: p?.phone ?? AuthService.instance.currentPhoneNumber,
    );
    _nationalIdCtrl = TextEditingController(text: p?.nationalId ?? '');
    _licenseNumberCtrl = TextEditingController(text: p?.licenseNumber ?? '');
    _photoUrl = p?.photoUrl;
    _licenseUrl = p?.licenseUrl;
    _idCardUrl = p?.idCardUrl;
    _criminalRecordUrl = p?.criminalRecordUrl;
    _drugTestUrl = p?.drugTestUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _nationalIdCtrl.dispose();
    _licenseNumberCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────
  // Image pickers — one per image type
  //
  // كل صورة تُرفع فورًا إلى الـ Backend (محمي بـ JWT) عند اختيارها، ثم يُحدَّث حقل
  // Firestore المناسب مباشرةً (photoUrl / licenseUrl / idCardUrl).
  // ────────────────────────────────────────────────────────

  /// يرفع [file] إلى الـ Backend (محمي بـ JWT) داخل [type] ويحدّث حقل
  /// [firestoreField] في Firestore مباشرةً فور نجاح الرفع. [setLocal]
  /// يحدّث المتغير المحلي المستخدم في بناء الملف الشخصي وعند الحفظ.
  Future<void> _uploadAndSetField({
    required File file,
    required UploadType type,
    required String firestoreField,
    required void Function(String url) setLocal,
    required String label,
  }) async {
    if (!mounted) return;
    setState(() => _isUploading = true);
    try {
      final uid = AuthService.instance.currentUser?.uid;
      final url = await ImageUploadService.instance.uploadImage(
        type: type,
        file: file,
      );
      if (!mounted) return;

      if (url == null) {
        _showUploadError(label);
        return;
      }

      setLocal(url);
      if (mounted) setState(() {});

      // تحديث حقل Firestore مباشرةً (merge — دون مسح باقي الحقول)
      if (uid != null) {
        await DriverRepository.instance.updateProfile(
          uid: uid,
          updates: {firestoreField: url},
        );
      }
    } catch (_) {
      if (mounted) _showUploadError(label);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showUploadError(String label) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر رفع $label. تحقق من الاتصال وحاول مرة أخرى.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picked = await pickImageWithSourceSheet(context);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _pickedPhoto = file);
    await _uploadAndSetField(
      file: file,
      type: UploadType.profile,
      firestoreField: 'photoUrl',
      setLocal: (url) => _photoUrl = url,
      label: 'الصورة الشخصية',
    );
  }

  Future<void> _pickLicense() async {
    final picked = await pickImageWithSourceSheet(context);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _pickedLicense = file);
    await _uploadAndSetField(
      file: file,
      type: UploadType.license,
      firestoreField: 'licenseUrl',
      setLocal: (url) => _licenseUrl = url,
      label: 'صورة الرخصة',
    );
  }

  Future<void> _pickIdCard() async {
    final picked = await pickImageWithSourceSheet(context);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _pickedIdCard = file);
    await _uploadAndSetField(
      file: file,
      type: UploadType.idCard,
      firestoreField: 'idCardUrl',
      setLocal: (url) => _idCardUrl = url,
      label: 'صورة الهوية',
    );
  }

  Future<void> _pickCriminalRecord() async {
    final picked = await pickImageWithSourceSheet(context);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _pickedCriminalRecord = file);
    await _uploadAndSetField(
      file: file,
      type: UploadType.idCard,
      firestoreField: 'criminalRecordUrl',
      setLocal: (url) => _criminalRecordUrl = url,
      label: 'الفيش الجنائى',
    );
  }

  Future<void> _pickDrugTest() async {
    final picked = await pickImageWithSourceSheet(context);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _pickedDrugTest = file);
    await _uploadAndSetField(
      file: file,
      type: UploadType.insurance,
      firestoreField: 'drugTestUrl',
      setLocal: (url) => _drugTestUrl = url,
      label: 'تحليل المخدرات',
    );
  }

  /// Builds a clickable image tile (existing URL or local file).
  ///
  /// When [uploading] is true a progress indicator is shown and taps are
  /// disabled so the captain cannot start another upload concurrently.
  Widget _imageTile({
    required String label,
    required String? imageUrl,
    required File? localFile,
    required VoidCallback onPick,
    bool uploading = false,
  }) {
    return GestureDetector(
      onTap: uploading ? null : onPick,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
              image: localFile != null
                  ? DecorationImage(
                      image: FileImage(localFile),
                      fit: BoxFit.cover,
                    )
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
          if (uploading)
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.darkBg.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 3),
            ),
        ],
      ),
    );
  }

  // ── Documents compliance note ────────────────────
  Widget _buildDocumentsNote() {
    final profile = widget.profile;
    if (profile == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final status = profile.compliance(now);
    if (status == DocumentCompliance.submitted) {
      return _noteChip('تم رفع المستندات المطلوبة ✓', AppColors.success);
    }
    if (status == DocumentCompliance.banned) {
      final until = profile.banUntil;
      final extra = until != null ? ' (حتى ${_fmtDate(until)})' : '';
      return _noteChip(
        'تم حظرك لعدم رفع المستندات المطلوبة$extra',
        AppColors.error,
      );
    }
    final daysLeft = profile.daysLeftInGrace(now);
    return _noteChip(
      'متبقٍ $daysLeft يوم لرفع المستندات قبل الحظر',
      AppColors.warning,
    );
  }

  Widget _noteChip(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall?.copyWith(color: color),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
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
      final repo = DriverRepository.instance;

      // صور الكابتن تُرفع مباشرةً إلى Cloudinary عند اختيارها وتُحدَّث
      // حقول Firestore الخاصة بها (photoUrl/licenseUrl/idCardUrl) فورًا،
      // لذا نُبقي قيم المتغيرات المحلية كما هي ونكتفي بحفظ باقي الحقول النصية.

      // 2. Build the profile object
      final now = DateTime.now();
      final profile = DriverProfile(
        uid: uid,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        photoUrl: _photoUrl,
        nationalId: _nationalIdCtrl.text.trim(),
        licenseNumber: _licenseNumberCtrl.text.trim(),
        vehicleType: widget.profile?.vehicleType ?? '',
        vehicleModel: widget.profile?.vehicleModel ?? '',
        vehicleColor: widget.profile?.vehicleColor ?? '',
        vehicleNumber: widget.profile?.vehicleNumber ?? '',
        licenseUrl: _licenseUrl,
        idCardUrl: _idCardUrl,
        criminalRecordUrl: _criminalRecordUrl,
        drugTestUrl: _drugTestUrl,
        documentsGraceEndsAt: widget.profile?.documentsGraceEndsAt,
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
                  // ── Images grid (بجانب بعض) ──────────────
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppSpacing.lg,
                    crossAxisSpacing: AppSpacing.lg,
                    childAspectRatio: 1,
                    children: [
                      Center(
                        child: _imageTile(
                          label: 'الصورة الشخصية',
                          imageUrl: _photoUrl,
                          localFile: _pickedPhoto,
                          onPick: _pickPhoto,
                          uploading: _isUploading,
                        ),
                      ),
                      Center(
                        child: _imageTile(
                          label: 'صورة البطاقة الشخصية',
                          imageUrl: _idCardUrl,
                          localFile: _pickedIdCard,
                          onPick: _pickIdCard,
                          uploading: _isUploading,
                        ),
                      ),
                      Center(
                        child: _imageTile(
                          label: 'صورة رخصة القيادة',
                          imageUrl: _licenseUrl,
                          localFile: _pickedLicense,
                          onPick: _pickLicense,
                          uploading: _isUploading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Required official documents ─────────
                  _label('المستندات الرسمية المطلوبة'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDocumentsNote(),
                  const SizedBox(height: AppSpacing.md),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppSpacing.lg,
                    crossAxisSpacing: AppSpacing.lg,
                    childAspectRatio: 1,
                    children: [
                      Center(
                        child: _imageTile(
                          label: 'الفيش الجنائى',
                          imageUrl: _criminalRecordUrl,
                          localFile: _pickedCriminalRecord,
                          onPick: _pickCriminalRecord,
                          uploading: _isUploading,
                        ),
                      ),
                      Center(
                        child: _imageTile(
                          label: 'تحليل المخدرات',
                          imageUrl: _drugTestUrl,
                          localFile: _pickedDrugTest,
                          onPick: _pickDrugTest,
                          uploading: _isUploading,
                        ),
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

                  // ── Phone (editable) ─────────────────────
                  _label('رقم الهاتف'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: AppTextStyles.bodyLarge,
                    decoration: _inputDecoration('أدخل رقم الهاتف'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'هذا الحقل مطلوب'
                        : null,
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
