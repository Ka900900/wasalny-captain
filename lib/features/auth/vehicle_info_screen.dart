import 'dart:io';

import 'package:flutter/material.dart';
import 'package:waslny_captain/widgets/image_source_picker.dart';

import 'package:waslny_captain/core/models/driver_profile.dart';
import 'package:waslny_captain/core/repositories/driver_repository.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/image_upload_service.dart';
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
  final String? phoneNumber; // رقم الهاتف من شاشة التسجيل
  const VehicleInfoScreen({super.key, this.captain, this.phoneNumber});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedModel;
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String _vehicleType = 'private';
  DriverProfile? _profile;
  String? _licenseUrl;
  File? _pickedLicense;
  String? _carPhotoUrl;
  File? _pickedCarPhoto;
  String? _phoneNumber; // رقم الهاتف من شاشة التسجيل

  static const List<String> _vehicleTypes = [
    'private',
    'taxi',
    'scooter',
    'motorcycle',
  ];

  static const Map<String, String> _vehicleTypesAr = {
    'private': 'ملاكي',
    'taxi': 'تاكسي',
    'scooter': 'سكوتر',
    'motorcycle': 'موتوسيكل',
  };

  /// أيقونات مناسبة لكل نوع مركبة (تستخدم في قائمة الاختيار).
  static const Map<String, IconData> _vehicleTypeIcons = {
    'private': Icons.directions_car_outlined,
    'taxi': Icons.local_taxi_outlined,
    'scooter': Icons.moped,
    'motorcycle': Icons.two_wheeler,
  };

  /// تحويل قيمة نوع المركبة المعروضة في التطبيق (صغيرة)
  /// إلى قيمة الـ Enum المتوقعة في الباك إند (كبيرة).
  static const Map<String, String> _vehicleTypeToBackend = {
    'private': 'PRIVATE_CAR',
    'taxi': 'TAXI',
    'scooter': 'SCOOTER',
    'motorcycle': 'MOTORCYCLE',
  };

  /// قائمة جاهزة بأشهر ماركات وموديلات السيارات (ملاكي/تاكسي)،
  /// مرتّبة حسب الماركة/الفئة لسهولة الاختيار في القائمة المنسدلة.
  static const Map<String, List<String>> _carModelsByCategory = {
    'تويوتا (Toyota)': [
      'Toyota Camry',
      'Toyota Corolla',
      'Toyota Yaris',
      'Toyota Land Cruiser',
    ],
    'هيونداى (Hyundai)': [
      'Hyundai Elantra',
      'Hyundai Tucson',
      'Hyundai Accent',
      'Hyundai Creta',
      'Hyundai Verna',
    ],
    'كيا (Kia)': ['Kia Sportage', 'Kia Cerato', 'Kia Picanto', 'Kia Rio'],
    'نيسان (Nissan)': ['Nissan Sunny', 'Nissan Sentra', 'Nissan Qashqai'],
    'MG': ['MG 5', 'MG 6', 'MG ZS'],
    'شيفروليه (Chevrolet)': ['Chevrolet Captiva', 'Chevrolet Aveo'],
    'رينو (Renault)': ['Renault Logan', 'Renault Duster'],
    'مازدا (Mazda)': ['Mazda 3', 'Mazda 6'],
    'سوزوكي (Suzuki)': ['Suzuki Swift', 'Suzuki Dzire'],
    'هوندا (Honda)': ['Honda Civic', 'Honda Accord'],
    'ميتسوبيشي (Mitsubishi)': ['Mitsubishi Lancer'],
    'فورد (Ford)': ['Ford Figo'],
    'السيارات الصينية': [
      'BYD Han',
      'BYD Qin',
      'BYD Song',
      'BYD Atto 3',
      'BYD Dolphin',
      'BYD Seal',
      'Geely Coolray',
      'Geely Emgrand',
      'Geely Tugella',
      'Geely Okavango',
      'Chery Tiggo 7',
      'Chery Tiggo 8',
      'Chery Arrizo 5',
      'Chery Tiggo 3x',
      'Changan Eado',
      'Changan CS35',
      'Changan CS55',
      'Changan Alsvin',
      'JAC J7',
      'JAC S3',
      'JAC S5',
      'Haval Jolion',
      'Haval H6',
      'Dongfeng AX7',
      'BAIC X35',
      'GAC GS3',
    ],
  };

  /// قائمة موديلات السكوتر (Scooter) الشائعة في السوق المصري.
  static const Map<String, List<String>> _scooterModelsByCategory = {
    'هوندا (Honda)': ['Honda PCX', 'Honda Click', 'Honda Dio'],
    'يامaha (Yamaha)': ['Yamaha NMAX', 'Yamaha Aerox', 'Yamaha Ray Z'],
    'سوزوكي (Suzuki)': ['Suzuki Burgman', 'Suzuki Access'],
    'تي فى اس (TVS)': ['TVS Ntorq', 'TVS Jupiter', 'TVS Scooty'],
    'بجاج (Bajaj)': ['Bajaj Chetak'],
    'ماركات أخرى': [
      'Vespa Primavera',
      'Kymco Agility',
      'SYM Mio',
      'Egyptian Moped (موتوسيكل مصري)',
    ],
  };

  /// قائمة موديلات الدراجات النارية (Motorcycle) الشائعة في السوق المصري.
  static const Map<String, List<String>> _motorcycleModelsByCategory = {
    'بجاج (Bajaj)': [
      'Bajaj Pulsar',
      'Bajaj Discover',
      'Bajaj CT 100',
      'Bajaj Boxer',
    ],
    'تي فى اس (TVS)': [
      'TVS Apache',
      'TVS Raider',
      'TVS Sport',
      'TVS Star City',
    ],
    'هوندا (Honda)': ['Honda CB', 'Honda Dream', 'Honda CG', 'Honda Navi'],
    'يامaha (Yamaha)': ['Yamaha FZ', 'Yamaha YBR', 'Yamaha RX'],
    'سوزوكي (Suzuki)': ['Suzuki Gixxer', 'Suzuki GS', 'Suzuki Intruder'],
    'ماركات أخرى': [
      'Hero Splendor',
      'Hero HF Deluxe',
      'Hero Passion',
      'Kawasaki Z',
      'Benelli TNT',
      'KTM Duke',
    ],
  };

  /// ترجع خريطة الموديلات المناسبة حسب نوع المركبة المختار.
  Map<String, List<String>> get _modelsByCategory {
    switch (_vehicleType) {
      case 'scooter':
        return _scooterModelsByCategory;
      case 'motorcycle':
        return _motorcycleModelsByCategory;
      default:
        return _carModelsByCategory;
    }
  }

  /// نسخة مسطّحة من موديلات نوع المركبة الحالي (للتحقق من القيمة المحفوظة).
  List<String> get _availableModels =>
      _modelsByCategory.values.expand((m) => m).toList();

  /// نسخة مسطّحة من كل الموديلات (كل الأنواع) — تُستخدم للتحقق من القيمة المحفوظة مسبقاً.
  static final List<String> _allModels = <String>{
    ..._carModelsByCategory.values.expand((m) => m),
    ..._scooterModelsByCategory.values.expand((m) => m),
    ..._motorcycleModelsByCategory.values.expand((m) => m),
  }.toList();

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

    // 1) تحديد رقم الهاتف من الـ widget مباشرة (متزامن، لا يحتاج context)
    if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) {
      _phoneNumber = widget.phoneNumber;
    }

    // 2) قراءة arguments فقط داخل addPostFrameCallback (يتجنّب .of(context) في initState)
    //    واستدعاء _loadProfile() هنا بعد التأكد من القيمة النهائية لـ _phoneNumber
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_phoneNumber == null || _phoneNumber!.isEmpty) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map && args['phoneNumber'] != null) {
          _phoneNumber = args['phoneNumber'] as String;
        }
      }
      _loadProfile();
    });
  }

  @override
  void dispose() {
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
                : 'private';
            _selectedModel = _allModels.contains(profile.vehicleModel)
                ? profile.vehicleModel
                : null;
            _colorController.text = profile.vehicleColor;
            _plateController.text = profile.vehicleNumber;
            _licenseUrl = profile.licenseUrl;
            _carPhotoUrl = profile.carPhotoUrl;
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
    final picked = await pickImageWithSourceSheet(context);
    if (picked != null) {
      setState(() {
        _pickedLicense = File(picked.path);
        _licenseUrl = null;
      });
    }
  }

  Future<void> _pickCarPhoto() async {
    final picked = await pickImageWithSourceSheet(context);
    if (picked != null) {
      setState(() {
        _pickedCarPhoto = File(picked.path);
        _carPhotoUrl = null;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // صورة السيارة إجبارية قبل الحفظ
    if (_pickedCarPhoto == null && _carPhotoUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إرفاق صورة السيارة (إجباري)'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final repo = DriverRepository.instance;
      final existing = _profile;

      if (_pickedLicense != null) {
        _licenseUrl = await ImageUploadService.instance.uploadImage(
          type: UploadType.license,
          file: _pickedLicense!,
        );
        // إن فشل الرفع (يرجع null) نوقف الحفظ فوراً ونُعلِم الكابتن
        if (_licenseUrl == null) {
          throw Exception(
            'تعذر رفع صورة الرخصة. تحقق من الاتصال وحاول مرة أخرى.',
          );
        }
      }

      // رفع صورة السيارة (إجبارية — تم التحقق من وجودها أعلى الدالة)
      if (_pickedCarPhoto != null) {
        _carPhotoUrl = await ImageUploadService.instance.uploadImage(
          type: UploadType.car,
          file: _pickedCarPhoto!,
        );
        if (_carPhotoUrl == null) {
          throw Exception(
            'تعذر رفع صورة السيارة. تحقق من الاتصال وحاول مرة أخرى.',
          );
        }
      }

      // Update the existing profile with vehicle fields
      final updatedProfile = DriverProfile(
        uid: uid,
        name: existing?.name ?? '',
        phone: existing?.phone ?? '',
        photoUrl: existing?.photoUrl,
        nationalId: existing?.nationalId,
        vehicleType: _vehicleType,
        vehicleModel: _selectedModel?.trim() ?? '',
        vehicleColor: _colorController.text.trim(),
        vehicleNumber: _plateController.text.trim(),
        licenseUrl: _licenseUrl,
        carPhotoUrl: _carPhotoUrl,
        criminalRecordUrl: existing?.criminalRecordUrl,
        drugTestUrl: existing?.drugTestUrl,
        documentsGraceEndsAt: existing?.documentsGraceEndsAt,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.saveProfile(updatedProfile);

      // 4. تسجيل الكابتن في الباك إند (يربط رقم الهاتف + بيانات العربية)
      final phone = _phoneNumber ?? updatedProfile.phone;
      if (phone.isEmpty) {
        throw Exception('رقم الهاتف غير متوفر للتسجيل');
      }
      await ApiService.instance.registerDriver(
        carModel: _selectedModel?.trim() ?? '',
        carPlateNumber: _plateController.text.trim(),
        carColor: _colorController.text.trim(),
        vehicleType:
            _vehicleTypeToBackend[_vehicleType] ?? _vehicleType.toUpperCase(),
        carPhotoUrl: _carPhotoUrl ?? '',
      );

      // Navigate to Home
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'حدث خطأ أثناء التسجيل';
        if (e is ApiException) {
          // 409 = رقم الهاتف مسجل لحساب تاني
          msg = e.message;
        } else {
          msg = 'حدث خطأ أثناء التسجيل: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
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
                                    child: Row(
                                      children: [
                                        Icon(
                                          _vehicleTypeIcons[type] ??
                                              Icons.category_outlined,
                                          color: AppColors.neonGreen,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(_vehicleTypesAr[type] ?? type),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _vehicleType = value;
                                      // إعادة ضبط الموديل لأن قائمة الموديلات تتغير حسب النوع
                                      _selectedModel = null;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 18),

                              // ── Vehicle Model (predefined list) ──
                              DropdownButtonFormField<String>(
                                initialValue: _selectedModel,
                                dropdownColor: AppColors.surfaceDark,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'موديل المركبة',
                                  prefixIcon: Icon(
                                    Icons.model_training,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                hint: const Text('اختر موديل السيارة'),
                                items: [
                                  for (final entry
                                      in _modelsByCategory.entries) ...[
                                    // عنوان الفئة/الماركة (غير قابل للاختيار)
                                    DropdownMenuItem<String>(
                                      enabled: false,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            color: AppColors.neonGreen,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // موديلات الفئة
                                    for (final m in entry.value)
                                      DropdownMenuItem<String>(
                                        value: m,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: Text(m),
                                        ),
                                      ),
                                  ],
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedModel = value);
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يرجى اختيار موديل المركبة';
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
                                    color: AppColors.textSecondary,
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
                                              color: AppColors.textSecondary,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'اضغط لاختيار صورة رخصة السيارة',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ── Car Photo (mandatory) ─────
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'صورة السيارة *',
                                  style: const TextStyle(
                                    color: AppColors.neonGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _pickCarPhoto,
                                child: Container(
                                  width: double.infinity,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceDark,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.neonGreen,
                                    ),
                                    image: _pickedCarPhoto != null
                                        ? DecorationImage(
                                            image: FileImage(_pickedCarPhoto!),
                                            fit: BoxFit.cover,
                                          )
                                        : (_carPhotoUrl != null
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    _carPhotoUrl!,
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null),
                                  ),
                                  child:
                                      _pickedCarPhoto == null &&
                                          _carPhotoUrl == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.directions_car_filled,
                                              color: AppColors.textSecondary,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'اضغط لإضافة صورة السيارة (إجباري)',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
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
