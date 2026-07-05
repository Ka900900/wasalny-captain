import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:waslny_captain/core/models/driver_profile.dart';
import 'package:waslny_captain/core/repositories/driver_repository.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// Vehicle Information screen for new captains (after Registration).
///
/// Collects:
/// - Vehicle Type (dropdown)
/// - Vehicle Model
/// - Vehicle Color
/// - Plate Number
///
/// On successful save, updates the existing captain profile in Firestore
/// and navigates to the Home screen.
class VehicleInfoScreen extends StatefulWidget {
  final dynamic captain; // optional CaptainModel
  const VehicleInfoScreen({super.key, this.captain});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String _vehicleType = 'Sedan';
  DriverProfile? _profile;
  String? _licenseUrl;
  File? _pickedLicense;

  static const List<String> _vehicleTypes = [
    'Sedan',
    'SUV',
    'Van',
    'Pickup',
    'Hatchback',
    'Minibus',
  ];

  static const Map<String, String> _vehicleTypesAr = {
    'Sedan': 'سيدان',
    'SUV': 'دفع رباعي',
    'Van': 'فان',
    'Pickup': 'نقل',
    'Hatchback': 'هاتشباك',
    'Minibus': 'ميكروباص',
  };

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
    _loadProfile();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────
  // Load existing profile
  // ──────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
      return;
    }
    try {
      final profile = await DriverRepository.instance.getProfile(uid);
      if (mounted) {
        setState(() {
          _profile = profile;
          if (profile != null) {
            _vehicleType = _vehicleTypes.contains(profile.vehicleType)
                ? profile.vehicleType
                : 'Sedan';
            _modelController.text = profile.vehicleModel;
            _colorController.text = profile.vehicleColor;
            _plateController.text = profile.vehicleNumber;
            _licenseUrl = profile.licenseUrl;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────
  // Save
  // ──────────────────────────────────────────────────────

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final repo = DriverRepository.instance;
      final existing = _profile;

      if (_pickedLicense != null) {
        _licenseUrl = await repo.uploadPickedFile(
          filePath: _pickedLicense!.path,
          folder: 'licenses',
        );
      }

      // Update the existing profile with vehicle fields
      final updatedProfile = DriverProfile(
        uid: uid,
        name: existing?.name ?? '',
        phone: existing?.phone ?? '',
        photoUrl: existing?.photoUrl,
        nationalId: existing?.nationalId,
        vehicleType: _vehicleType,
        vehicleModel: _modelController.text.trim(),
        vehicleColor: _colorController.text.trim(),
        vehicleNumber: _plateController.text.trim(),
        licenseUrl: _licenseUrl,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.saveProfile(updatedProfile);

      // Navigate to Home
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
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
            center: Alignment.center,
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
            child: _isLoading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.neonGreen,
                    ),
                  )
                : SingleChildScrollView(
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
                              // ── Header icon ────────────────
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.neonGreen.withValues(
                                    alpha: 0.1,
                                  ),
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
                                  Icons.directions_car_outlined,
                                  color: AppColors.neonGreen,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── Title ──────────────────────
                              Text(
                                'معلومات المركبة',
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(color: AppColors.neonGreen),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'أدخل بيانات مركبتك لبدء استقبال الرحلات',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 36),

                              // ── Vehicle Type ──────────────
                              DropdownButtonFormField<String>(
                                initialValue: _vehicleType,
                                dropdownColor: AppColors.surfaceDark,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'نوع المركبة',
                                  prefixIcon: Icon(
                                    Icons.category_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                items: _vehicleTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      '${_vehicleTypesAr[type] ?? type} ($type)',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _vehicleType = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 18),

                              // ── Vehicle Model ─────────────
                              TextFormField(
                                controller: _modelController,
                                keyboardType: TextInputType.text,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'مثال: تويوتا كامري 2024',
                                  labelText: 'موديل المركبة',
                                  prefixIcon: Icon(
                                    Icons.model_training,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يرجى إدخال موديل المركبة';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // ── Vehicle Color ─────────────
                              TextFormField(
                                controller: _colorController,
                                keyboardType: TextInputType.text,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'مثال: أبيض, أسود, فضي',
                                  labelText: 'لون المركبة',
                                  prefixIcon: Icon(
                                    Icons.palette_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يرجى إدخال لون المركبة';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // ── Plate Number ──────────────
                              TextFormField(
                                controller: _plateController,
                                keyboardType: TextInputType.text,
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'مثال: أ ب ج 1234',
                                  labelText: 'رقم اللوحة',
                                  prefixIcon: Icon(
                                    Icons.confirmation_number_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يرجى إدخال رقم اللوحة';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // ── License upload ────────────
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'صورة رخصة السيارة',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _pickLicense,
                                child: Container(
                                  width: double.infinity,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceDark,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.textSecondary,
                                    ),
                                    image: _pickedLicense != null
                                        ? DecorationImage(
                                            image: FileImage(_pickedLicense!),
                                            fit: BoxFit.cover,
                                          )
                                        : (_licenseUrl != null
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    _licenseUrl!,
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null),
                                  ),
                                  child:
                                      _pickedLicense == null &&
                                          _licenseUrl == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.camera_alt_outlined,
                                              color: Colors.white70,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'اضغط لاختيار صورة رخصة السيارة',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 36),

                              // ── Save button ───────────────
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
                                      : const Text('حفظ وبدء الرحلات'),
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
