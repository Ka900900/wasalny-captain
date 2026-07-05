import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:waslny_captain/core/models/driver_profile.dart';
import 'package:waslny_captain/core/repositories/driver_repository.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
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
  /// The phone number (without country code) passed from the OTP screen.
  final String phoneNumber;

  const RegistrationScreen({super.key, required this.phoneNumber});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();

  bool _isSaving = false;

  // ── Profile photo ────────────────────────────────────
  File? _pickedPhoto;
  String? _uploadedPhotoUrl;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────
  // Image picker
  // ──────────────────────────────────────────────────────

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

      final repo = DriverRepository.instance;

      // 1. Upload photo if picked
      if (_pickedPhoto != null) {
        _uploadedPhotoUrl = await repo.uploadPickedFile(
          filePath: _pickedPhoto!.path,
          folder: 'photos',
        );
      }

      // 2. Build the profile
      final fullPhone = '+20${widget.phoneNumber}';
      final now = DateTime.now();
      final profile = DriverProfile(
        uid: uid,
        name: _nameController.text.trim(),
        phone: fullPhone,
        photoUrl: _uploadedPhotoUrl,
        nationalId: _nationalIdController.text.trim(),
        vehicleType: '',
        vehicleModel: '',
        vehicleColor: '',
        vehicleNumber: '',
        createdAt: now,
        updatedAt: now,
      );

      // 3. Persist to Firestore
      await repo.createProfile(profile);

      // 4. Navigate to Vehicle Information
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/vehicle-info');
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
                                    : null,
                                child: _pickedPhoto == null
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
