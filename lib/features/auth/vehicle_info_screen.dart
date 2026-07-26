import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waslny_captain/widgets/image_source_picker.dart';

import 'package:waslny_captain/core/network/api_exceptions.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/image_upload_service.dart';
import 'package:waslny_captain/core/services/document_upload_service.dart';
import 'package:waslny_captain/features/verification/camera_screen.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/features/auth/verification_pending_screen.dart';

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

  /// بيانات ملف Google الشخصي (تُستخدم للتعبئة المسبقة عند تسجيل الدخول عبر Google).
  final String? googleName;
  final String? googleEmail;
  final String? googlePhotoUrl;

  const VehicleInfoScreen({
    super.key,
    this.captain,
    this.phoneNumber,
    this.googleName,
    this.googleEmail,
    this.googlePhotoUrl,
  });

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedModel;
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String _vehicleType = 'private';
  String? _licenseUrl;
  String? _licenseBackUrl;
  String? _idCardUrl;
  String? _idCardBackUrl;
  String? _carPhotoUrl;
  File? _pickedCarPhoto;
  String? _vehicleLicenseFrontUrl;
  String? _vehicleLicenseBackUrl;
  String? _criminalRecordUrl;
  File? _pickedCriminalRecord;
  String? _drugTestUrl;
  File? _pickedDrugTest;
  final TextEditingController _licenseNumberCtrl = TextEditingController();
  String? _phoneNumber; // رقم الهاتف من شاشة التسجيل
  String? _nationalId; // الرقم القومي من شاشة التسجيل

  /// اسم المستخدم من Google (يُعرض في بطاقة المستخدم ويُستخدم عند الحفظ).
  String? _googleName;
  String? _googleEmail;
  String? _googlePhotoUrl;

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

    // 1) قراءة بيانات Google من الـ widget مباشرة
    if (widget.googleName != null && widget.googleName!.isNotEmpty) {
      _googleName = widget.googleName;
    }
    if (widget.googleEmail != null && widget.googleEmail!.isNotEmpty) {
      _googleEmail = widget.googleEmail;
    }
    if (widget.googlePhotoUrl != null && widget.googlePhotoUrl!.isNotEmpty) {
      _googlePhotoUrl = widget.googlePhotoUrl;
    }

    // 2) تحديد رقم الهاتف من الـ widget مباشرة
    if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) {
      _phoneNumber = widget.phoneNumber;
    }

    // 3) قراءة arguments داخل addPostFrameCallback (يتجنّب .of(context) في initState)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        // قراءة رقم الهاتف من الـ arguments
        if ((_phoneNumber == null || _phoneNumber!.isEmpty) &&
            args['phoneNumber'] != null) {
          _phoneNumber = args['phoneNumber'] as String;
        }
        // قراءة بيانات Google من الـ arguments إذا لم تكن قد أعطيت للـ widget
        if ((_googleName == null || _googleName!.isEmpty) &&
            args['name'] != null) {
          _googleName = args['name'] as String? ?? '';
        }
        if ((_googleEmail == null || _googleEmail!.isEmpty) &&
            args['email'] != null) {
          _googleEmail = args['email'] as String? ?? '';
        }
        if ((_googlePhotoUrl == null || _googlePhotoUrl!.isEmpty) &&
            args['photoUrl'] != null) {
          _googlePhotoUrl = args['photoUrl'] as String? ?? '';
        }
        if (args['nationalId'] != null) {
          _nationalId = args['nationalId'] as String;
        }
      }
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _colorController.dispose();
    _plateController.dispose();
    _phoneController.dispose();
    _licenseNumberCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────
  // Load existing profile
  // ──────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    // No Firestore read needed — backend API is the source of truth.
    // Form is used only for new registration (existing users skip to /home).
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────
  // User Info Card (Google pre‑filled data)
  // ──────────────────────────────────────────────────────

  /// Builds a card showing the Google profile data at the top of the form.
  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.primaryFaded),
      ),
      child: Row(
        children: [
          // Profile photo
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryContainer,
            backgroundImage:
                (_googlePhotoUrl != null && _googlePhotoUrl!.isNotEmpty)
                ? NetworkImage(_googlePhotoUrl!)
                : null,
            child: (_googlePhotoUrl == null || _googlePhotoUrl!.isEmpty)
                ? const Icon(Icons.person, color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          // Name + Email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _googleName ?? '',
                  style: AppTextStyles.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_googleEmail != null && _googleEmail!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _googleEmail!,
                      style: AppTextStyles.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  ),
                  child: Text(
                    'حساب Google',
                    style: AppTextStyles.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Edit icon (optional)
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  // Save
  // ──────────────────────────────────────────────────────

  /// Opens custom camera, captures with retake option, then uploads immediately.
  Future<File?> _captureWithRetake() async {
    while (true) {
      if (!mounted) return null;
      final result = await Navigator.of(context).push<CameraCaptureResult>(
        MaterialPageRoute(
          builder: (_) => const CameraScreen(mode: CaptureMode.document),
        ),
      );
      if (result == null) return null;
      final file = File(result.filePath);
      if (!mounted) return null;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          content: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(file, height: 300, fit: BoxFit.contain),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'إعادة',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonGreen,
              ),
              child: const Text('تأكيد', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
      if (confirmed == true) return file;
    }
  }

  Future<void> _captureAndUploadDoc({
    required UploadDocType docType,
    required void Function(String url) onUrl,
    required String label,
  }) async {
    final file = await _captureWithRetake();
    if (file == null || !mounted) return;

    try {
      final result = await DocumentUploadService.instance
          .uploadImage(docType: docType, file: file)
          .first;
      if (result.success && result.imageUrl != null && mounted) {
        setState(() => onUrl(result.imageUrl!));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل رفع $label: ${result.error ?? 'خطأ غير معروف'}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء رفع $label'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _captureIdCardFront() => _captureAndUploadDoc(
    docType: UploadDocType.idFront,
    onUrl: (url) => _idCardUrl = url,
    label: 'البطاقة (وجه)',
  );

  Future<void> _captureIdCardBack() => _captureAndUploadDoc(
    docType: UploadDocType.idBack,
    onUrl: (url) => _idCardBackUrl = url,
    label: 'البطاقة (ظهر)',
  );

  Future<void> _captureLicenseFront() => _captureAndUploadDoc(
    docType: UploadDocType.license,
    onUrl: (url) => _licenseUrl = url,
    label: 'الرخصة (وجه)',
  );

  Future<void> _captureLicenseBack() => _captureAndUploadDoc(
    docType: UploadDocType.licenseBack,
    onUrl: (url) => _licenseBackUrl = url,
    label: 'الرخصة (ظهر)',
  );

  Future<void> _captureVehicleLicenseFront() => _captureAndUploadDoc(
    docType: UploadDocType.vehicleLicenseFront,
    onUrl: (url) => _vehicleLicenseFrontUrl = url,
    label: 'رخصة السيارة (وجه)',
  );

  Future<void> _captureVehicleLicenseBack() => _captureAndUploadDoc(
    docType: UploadDocType.vehicleLicenseBack,
    onUrl: (url) => _vehicleLicenseBackUrl = url,
    label: 'رخصة السيارة (ظهر)',
  );

  Widget _buildDocPreview({required String label, required String? imageUrl}) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: imageUrl != null
              ? AppColors.neonGreen
              : AppColors.textSecondary,
        ),
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.textSecondary,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          : Stack(
              alignment: Alignment.topRight,
              children: [
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.neonGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _pickCriminalRecord() async {
    final picked = await pickImageWithSourceSheet(context);
    if (picked != null) {
      setState(() {
        _pickedCriminalRecord = File(picked.path);
        _criminalRecordUrl = null;
      });
    }
  }

  Future<void> _pickDrugTest() async {
    final picked = await pickImageWithSourceSheet(context);
    if (picked != null) {
      setState(() {
        _pickedDrugTest = File(picked.path);
        _drugTestUrl = null;
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

      // No Firestore read/write — backend API is the source of truth.

      // License and ID card images are uploaded immediately after capture
      // via _captureAndUploadDoc, so no upload needed here.

      if (_pickedCriminalRecord != null) {
        _criminalRecordUrl = await ImageUploadService.instance.uploadImage(
          type: UploadType.idCard,
          file: _pickedCriminalRecord!,
        );
        if (_criminalRecordUrl == null) {
          throw Exception(
            'تعذر رفع الفيش الجنائى. تحقق من الاتصال وحاول مرة أخرى.',
          );
        }
      }

      if (_pickedDrugTest != null) {
        _drugTestUrl = await ImageUploadService.instance.uploadImage(
          type: UploadType.insurance,
          file: _pickedDrugTest!,
        );
        if (_drugTestUrl == null) {
          throw Exception(
            'تعذر رفع تحليل المخدرات. تحقق من الاتصال وحاول مرة أخرى.',
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

      final phoneCtrl = _phoneController.text.trim();
      final phone =
          _phoneNumber ?? (phoneCtrl.isNotEmpty ? phoneCtrl : null) ?? '';
      if (phone.isEmpty) {
        throw Exception('رقم الهاتف غير متوفر للتسجيل');
      }

      // ── Validate phone doesn't contain firebase: placeholder ──
      if (phone.startsWith('firebase:')) {
        throw Exception('رقم الهاتف غير صالح. يرجى إدخال رقم هاتف حقيقي.');
      }

      // ── التحقق من الحقول المطلوبة قبل إرسال الـ API ──────────
      if (_selectedModel == null || _selectedModel!.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى اختيار موديل المركبة'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      if (_plateController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى إدخال رقم اللوحة'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      if (_colorController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى إدخال لون المركبة'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // 4. تسجيل الكابتن في الباك إند (يربط رقم الهاتف + بيانات العربية + بيانات Google)
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('📋 _save → registerDriver request:');
      debugPrint('   carModel:        ${_selectedModel?.trim() ?? ''}');
      debugPrint('   carPlateNumber:  ${_plateController.text.trim()}');
      debugPrint('   carColor:        ${_colorController.text.trim()}');
      debugPrint(
        '   vehicleType:     ${_vehicleTypeToBackend[_vehicleType] ?? _vehicleType.toUpperCase()}',
      );
      debugPrint('   carPhotoUrl:     ${_carPhotoUrl ?? ''}');
      debugPrint('   name:            $_googleName');
      debugPrint('   email:           $_googleEmail');
      debugPrint('   photoUrl:        $_googlePhotoUrl');
      debugPrint('   phoneNumber:     $phone');
      debugPrint(
        '   criminalRecord:  ${_criminalRecordUrl != null ? 'present' : 'null'}',
      );
      debugPrint(
        '   drugTest:        ${_drugTestUrl != null ? 'present' : 'null'}',
      );
      debugPrint('═══════════════════════════════════════════════════');

      await ApiService.instance.registerDriver(
        carModel: _selectedModel?.trim() ?? '',
        carPlateNumber: _plateController.text.trim(),
        carColor: _colorController.text.trim(),
        vehicleType:
            _vehicleTypeToBackend[_vehicleType] ?? _vehicleType.toUpperCase(),
        carPhotoUrl: _carPhotoUrl ?? '',
        name: _googleName,
        email: _googleEmail,
        photoUrl: _googlePhotoUrl,
        phoneNumber: phone,
        nationalId: _nationalId,
        idCardUrl: _idCardUrl,
        idCardBackUrl: _idCardBackUrl,
        licenseUrl: _licenseUrl,
        licenseBackUrl: _licenseBackUrl,
        licenseNumber: _licenseNumberCtrl.text.trim(),
        vehicleLicenseFrontUrl: _vehicleLicenseFrontUrl,
        vehicleLicenseBackUrl: _vehicleLicenseBackUrl,
        criminalRecordUrl: _criminalRecordUrl,
        drugTestUrl: _drugTestUrl,
      );

      // Navigate to verification pending (new registration is always PENDING)
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('✅ _save → registerDriver SUCCESS — navigating to verification pending');
      debugPrint('═══════════════════════════════════════════════════');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const VerificationPendingScreen(),
          ),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String msg;
        if (e is ApiException) {
          msg = e.message;
        } else if (e is DioException) {
          // محاولة استخراج رسالة الخطأ من رد الباك إند
          final data = e.response?.data;
          if (data != null) {
            if (data is Map) {
              msg =
                  (data['message'] ??
                          data['error'] ??
                          data['msg'] ??
                          data.toString())
                      .toString();
            } else {
              msg = data.toString();
            }
          } else {
            msg = 'خطأ في الاتصال بالخادم (${e.response?.statusCode ?? ''})';
          }
        } else {
          msg = 'حدث خطأ أثناء التسجيل: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle(fontSize: 14)),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'نسخ',
              textColor: Colors.white,
              onPressed: () {
                // نسخ الخطأ للحافظة (يتم عبر Clipboard)
              },
            ),
          ),
        );
        // طباعة الخطأ كاملاً في الـ console
        debugPrint('🧨 _save catch-block: $e');
        debugPrint('🧨 ERROR TYPE: ${e.runtimeType}');
        if (e is ApiException) {
          debugPrint('🧨 ApiException statusCode: ${e.statusCode}');
          debugPrint('🧨 ApiException message: ${e.message}');
        }
        if (e is DioException) {
          debugPrint('🧨 DioException type: ${e.type}');
          debugPrint('🧨 response.statusCode: ${e.response?.statusCode}');
          debugPrint('🧨 response.data: ${e.response?.data}');
          debugPrint('🧨 response.headers: ${e.response?.headers}');
          debugPrint('🧨 requestOptions.uri: ${e.requestOptions.uri}');
          debugPrint('⬤ requestOptions.method: ${e.requestOptions.method}');
          debugPrint('🧨 requestOptions.data: ${e.requestOptions.data}');
          debugPrint('🧨 requestOptions.headers: ${e.requestOptions.headers}');
        }
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
                              const SizedBox(height: 24),

                              // ── Google User Info Card ─────
                              if (_googleName != null &&
                                  _googleName!.isNotEmpty)
                                _buildUserInfoCard(),
                              if (_googleName != null &&
                                  _googleName!.isNotEmpty)
                                const SizedBox(height: 24),

                              // ── Phone Number (Google users) ─
                              if (_googleName != null &&
                                  _googleName!.isNotEmpty &&
                                  (_phoneNumber == null ||
                                      _phoneNumber!.isEmpty)) ...[
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
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                              ],

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

                              // ── License Number ────────────
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'رقم رخصة القيادة',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _licenseNumberCtrl,
                                keyboardType: TextInputType.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'أدخل رقم رخصة القيادة',
                                  labelText: 'رقم الرخصة',
                                  prefixIcon: Icon(
                                    Icons.badge_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ── ID Card ────────────────────
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'البطاقة الشخصية',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _captureIdCardFront,
                                      child: _buildDocPreview(
                                        label: 'الوجه الأمامي',
                                        imageUrl: _idCardUrl,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _captureIdCardBack,
                                      child: _buildDocPreview(
                                        label: 'الوجه الخلفي',
                                        imageUrl: _idCardBackUrl,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // ── License ────────────────────
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'رخصة القيادة',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _captureLicenseFront,
                                      child: _buildDocPreview(
                                        label: 'الوجه الأمامي',
                                        imageUrl: _licenseUrl,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _captureLicenseBack,
                                      child: _buildDocPreview(
                                        label: 'الوجه الخلفي',
                                        imageUrl: _licenseBackUrl,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // ── Vehicle License ───────────
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'رخصة السيارة / الموتوسيكل',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _captureVehicleLicenseFront,
                                      child: _buildDocPreview(
                                        label: 'الوجه الأمامي',
                                        imageUrl: _vehicleLicenseFrontUrl,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _captureVehicleLicenseBack,
                                      child: _buildDocPreview(
                                        label: 'الوجه الخلفي',
                                        imageUrl: _vehicleLicenseBackUrl,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // ── Criminal Record upload ────
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'الفيش الجنائى',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _pickCriminalRecord,
                                child: Container(
                                  width: double.infinity,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceDark,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          _criminalRecordUrl != null ||
                                              _pickedCriminalRecord != null
                                          ? AppColors.neonGreen
                                          : AppColors.textSecondary,
                                    ),
                                    image: _pickedCriminalRecord != null
                                        ? DecorationImage(
                                            image: FileImage(
                                              _pickedCriminalRecord!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : (_criminalRecordUrl != null
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    _criminalRecordUrl!,
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null),
                                  ),
                                  child:
                                      _pickedCriminalRecord == null &&
                                          _criminalRecordUrl == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.description_outlined,
                                              color: AppColors.textSecondary,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'اضغط لاختيار الفيش الجنائى',
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
                              const SizedBox(height: 6),
                              Text(
                                '(اختياري الآن - متاح استكماله خلال 30 يوم من التسجيل)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ── Drug Test upload ──────────
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'تحليل المخدرات',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _pickDrugTest,
                                child: Container(
                                  width: double.infinity,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceDark,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          _drugTestUrl != null ||
                                              _pickedDrugTest != null
                                          ? AppColors.neonGreen
                                          : AppColors.textSecondary,
                                    ),
                                    image: _pickedDrugTest != null
                                        ? DecorationImage(
                                            image: FileImage(_pickedDrugTest!),
                                            fit: BoxFit.cover,
                                          )
                                        : (_drugTestUrl != null
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    _drugTestUrl!,
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null),
                                  ),
                                  child:
                                      _pickedDrugTest == null &&
                                          _drugTestUrl == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.medication_outlined,
                                              color: AppColors.textSecondary,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'اضغط لاختيار تحليل المخدرات',
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
                              const SizedBox(height: 6),
                              Text(
                                '(اختياري الآن - متاح استكماله خلال 30 يوم من التسجيل)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
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
