import 'dart:io';

import 'package:flutter/material.dart';
import 'package:waslny_captain/widgets/image_source_picker.dart';

import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/image_upload_service.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// Registration screen for new captains (first login).
///
/// Collects:
/// - Full Name
/// - National ID
/// - Profile Photo (optional)
///
/// On successful save, creates the captain profile in Firestore and
/// navigates to the Home screen.
class RegistrationScreen extends StatefulWidget {
  /// Optional phone number (may be null when using Google Sign-In).
  final String? phoneNumber;

  /// Google profile data for pre‑filling the form.
  final String? googleName;
  final String? googleEmail;
  final String? googlePhotoUrl;

  const RegistrationScreen({
    super.key,
    this.phoneNumber,
    this.googleName,
    this.googleEmail,
    this.googlePhotoUrl,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isSaving = false;

  // ── Profile photo ────────────────────────────────────
  File? _pickedPhoto;
  String? _uploadedPhotoUrl;

  /// Google profile data for passing through to VehicleInfoScreen.
  String? _googleName;
  String? _googleEmail;
  String? _googlePhotoUrl;

  // ── Animation ────────────────────────────────────────
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );
    _animController.forward();

    // Store Google profile data for pre‑filling & passing through
    if (widget.googleName != null && widget.googleName!.isNotEmpty) {
      _googleName = widget.googleName;
      _nameController.text = widget.googleName!;
    }
    if (widget.googleEmail != null && widget.googleEmail!.isNotEmpty) {
      _googleEmail = widget.googleEmail;
    }
    if (widget.googlePhotoUrl != null && widget.googlePhotoUrl!.isNotEmpty) {
      _googlePhotoUrl = widget.googlePhotoUrl;
    }

    // Pre‑fill phone number from argument if provided
    if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) {
      _phoneController.text = widget.phoneNumber!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────
  // Image picker
  // ──────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picked = await pickImageWithSourceSheet(context);
    if (picked != null) {
      setState(() {
        _pickedPhoto = File(picked.path);
        _uploadedPhotoUrl = null; // will be uploaded on save
      });
    }
  }

  // ──────────────────────────────────────────────────────
  // Save
  // ──────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // 1. Upload photo if picked (عبر الـ Backend المحمي بـ JWT)
      if (_pickedPhoto != null) {
        _uploadedPhotoUrl = await ImageUploadService.instance.uploadImage(
          type: UploadType.profile,
          file: _pickedPhoto!,
        );
      }

      // 2. Navigate to Vehicle Information
      final String fullPhone = _phoneController.text.trim();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/vehicle-info',
          arguments: <String, dynamic>{
            'phoneNumber': fullPhone,
            'name': _googleName,
            'email': _googleEmail,
            'photoUrl': _uploadedPhotoUrl ?? _googlePhotoUrl,
            'nationalId': _nationalIdController.text.trim(),
          },
        );
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

  // ──────────────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.8,
            colors: [
              AppColors.neonGreen.withValues(alpha: 0.06),
              AppColors.darkBg,
              AppColors.darkBg,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Header icon ──────────────────────
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.neonGreen.withValues(alpha: 0.1),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonGreen.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 25,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: AppColors.neonGreen,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Title ────────────────────────────
                        Text(
                          'إنشاء حساب جديد',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(color: AppColors.neonGreen),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'أدخل بياناتك الشخصية للتسجيل',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 36),

                        // ── Profile photo ────────────────────
                        GestureDetector(
                          onTap: _pickPhoto,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: AppColors.glassBg,
                                backgroundImage: _pickedPhoto != null
                                    ? FileImage(_pickedPhoto!)
                                    : (_googlePhotoUrl != null
                                          ? NetworkImage(_googlePhotoUrl!)
                                          : null),
                                child:
                                    _pickedPhoto == null &&
                                        _googlePhotoUrl == null
                                    ? const Icon(
                                        Icons.camera_alt,
                                        color: AppColors.textSecondary,
                                        size: 32,
                                      )
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.neonGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Full Name ────────────────────────
                        TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'مثال: أحمد علي',
                            labelText: 'الاسم الكامل',
                            prefixIcon: Icon(
                              Icons.person,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال الاسم الكامل';
                            }
                            if (value.trim().length < 3) {
                              return 'الاسم يجب أن يتكون من 3 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // ── National ID ──────────────────────
                        TextFormField(
                          controller: _nationalIdController,
                          keyboardType: TextInputType.number,
                          maxLength: 14,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'XXXXXXXXXXXXXX',
                            labelText: 'الرقم القومي',
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال الرقم القومي';
                            }
                            if (value.trim().length < 14) {
                              return 'الرقم القومي يجب أن يتكون من 14 رقماً';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // ── Phone Number ──────────────────────
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: '01xxxxxxxxx',
                            labelText: 'رقم الهاتف',
                            prefixIcon: Icon(
                              Icons.phone,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال رقم الهاتف';
                            }
                            // يقبل 01xxxxxxxxx أو +201xxxxxxxxx
                            final regex = RegExp(r'^(?:\+20|0)1\d{9}$');
                            if (!regex.hasMatch(value.trim())) {
                              return 'رقم الهاتف المصري غير صحيح (مثال: 01xxxxxxxxx)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // ── Save button ──────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text('إنشاء حساب'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
