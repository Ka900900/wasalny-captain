import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:geolocator/geolocator.dart';

import 'package:waslny_captain/core/design_system/design_system.dart';
import 'package:waslny_captain/core/network/api_exceptions.dart';
import 'package:waslny_captain/core/services/database_service.dart';
import 'package:waslny_captain/core/models/driver_profile.dart';
import 'package:waslny_captain/core/models/ride_model.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/services/sound_service.dart';
import 'package:waslny_captain/core/services/realtime_service.dart';
import 'package:waslny_captain/core/services/socket_service.dart';
import 'package:waslny_captain/features/profile/edit_profile_screen.dart';
import 'package:waslny_captain/core/widgets/route_transitions.dart';
import 'package:waslny_captain/features/trips/trips_screen.dart';
import 'package:waslny_captain/features/wallet/wallet_screen.dart';
import 'package:waslny_captain/features/profile/profile_screen.dart';
import 'package:waslny_captain/features/notifications/notifications_screen.dart';
import 'package:waslny_captain/features/chat/chat_screen.dart';

import 'widgets/home_map_widget.dart';
import 'widgets/ride_request_card.dart';
import 'widgets/trip_status_card.dart';
import 'widgets/online_waiting_card.dart';
import 'widgets/online_toggle_button.dart';

/// Main captain home screen with Material 3 bottom navigation.
///
/// Single source of truth for online/offline: `_isOnline`.
/// The status badge at the top-right is the ONLY controller.
class CaptainHomeScreen extends StatefulWidget {
  const CaptainHomeScreen({super.key});

  @override
  State<CaptainHomeScreen> createState() => _CaptainHomeScreenState();
}

class _CaptainHomeScreenState extends State<CaptainHomeScreen> {
  // ── Tab state ─────────────────────────────────────────
  int _selectedIndex = 0;

  // ── Online / Offline (single source of truth) ─────────
  bool _isOnline = false;
  final DatabaseService _dbService = DatabaseService();

  // ── Location permissions ─────────────────────────────
  bool _locationGranted = false;

  // ── OpenStreetMap ────────────────────────────────────
  late final osm.MapController mapController;
  bool _mapReady = false;

  // ── Periodic location upload (only when online) ──────
  Timer? _locationTimer;

  // ── Active trip workflow ──────────────────────────
  String? _activeTripId;

  // ── Current incoming ride request (Phase 1) ───────
  RideModel? _currentRideRequest;

  // ── Ride-alert sound toggle (used by the waiting card) ──
  bool _soundEnabled = true;

  // ── Profile from backend API (document compliance / ban status) ──
  DriverProfile? _profile;

  // ── Toggle loading state ───────────────────────────
  bool _isToggling = false;

  // ── Stats header data ──────────────────────────────
  double _earningsToday = 0;
  int _tripsToday = 0;
  double _rating = 0;
  // int _totalRatings = 0;

  // ──────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    mapController = osm.MapController.withPosition(
      initPosition: osm.GeoPoint(latitude: 30.0444, longitude: 31.2357),
    );

    // جلب البروفايل من الباك إند بدلاً من Firestore
    _fetchProfile();

    // ── استقبال طلبات الرحلات عبر السوكيت (بديل آمن عن مستمع Firestore العام) ──
    // حدث لحظي من الباك إند للكابتن المخصّص فقط → اعرض الكارت + شغّل صوت التنبيه.
    SocketService().onNewAvailableRide = (ride) {
      if (!mounted) return;
      setState(() => _currentRideRequest = ride);
      // شغّل صوت التنبيه المتكرر لجذب انتباه الكابتن.
      SoundService.instance.playLoopingAlert();
      // لا نبدأ تتبّع حالة الرحلة هنا — ننتظر نجاح القبول (status → accepted)
      // لربط مستندها الخاص في Firestore عبر startRideStatusListenerById.
    };

    // أي تغيير في حالة الرحلة (من Firestore) → حدّث الكارت فوراً
    RealtimeService.instance.onRideStatusChanged = (updatedRide) {
      if (!mounted) return;
      // انتهت الرحلة: صفّر الكارت + أظهر رسالة نجاح
      if (updatedRide.status == RideStatus.completed) {
        RealtimeService.instance.stopRideStatusListener();
        _activeTripId = null;
        setState(() => _currentRideRequest = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'انتهت الرحلة بنجاح — يمكنك استلام التقييم والأرباح قريباً.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        return;
      }
      setState(() => _currentRideRequest = updatedRide);
    };

    // إلغاء الرحلة (من العميل/الباك إند) → أخفِ الكارت + SnackBar
    RealtimeService.instance.onRideCancelled = () {
      if (!mounted) return;
      RealtimeService.instance.stopRideStatusListener();
      _activeTripId = null;
      setState(() => _currentRideRequest = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إلغاء الرحلة من قبل العميل.'),
          backgroundColor: AppColors.error,
        ),
      );
    };

    // لا يوجد مستمع لرحلات معلّقة عبر Firestore بعد الآن (استُبدل بالسوكيت).

    // جلب إحصائيات اليوم وعرضها في الـ Header
    _fetchStats();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _locationTimer = null;
    RealtimeService.instance.stopRideListener();
    RealtimeService.instance.stopRideStatusListener();
    SocketService().disconnect();
    super.dispose();
  }

  Future<void> _enableMapTracking() async {
    try {
      await mapController.currentLocation();
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────
  // Location Permission
  // ──────────────────────────────────────────────────────

  Future<void> _checkLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تشغيل خدمة الموقع'),
            backgroundColor: AppColors.warning,
          ),
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('صلاحية الموقع مطلوبة للتطبيق'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'صلاحية الموقع مرفوضة بشكل دائم. يرجى تفعيلها من الإعدادات',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (mounted) setState(() => _locationGranted = true);
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────
  // Fetch stats for header bar
  // ──────────────────────────────────────────────────────

  Future<void> _fetchStats() async {
    try {
      // Today's earnings
      if (ApiService.backendEnabled) {
        final earnings = await ApiService.instance.getEarnings(period: 'daily');
        if (mounted) {
          setState(() {
            _earningsToday =
                ((earnings['totalAmount'] ?? earnings['amount'] ?? 0) as num)
                    .toDouble();
            _tripsToday =
                ((earnings['totalTrips'] ?? earnings['trips'] ?? 0) as num)
                    .toInt();
          });
        }
      }
      // Driver rating
      if (ApiService.backendEnabled) {
        final ratings = await ApiService.instance.getDriverRatings();
        if (mounted) {
          setState(() {
            _rating =
                ((ratings['averageRating'] ?? ratings['rating'] ?? 0) as num)
                    .toDouble();
            /*_totalRatings =
                ((ratings['totalRatings'] ?? ratings['count'] ?? 0) as num)
                    .toInt();*/
          });
        }
      }
    } on ApiException catch (e) {
      debugPrint('HomeScreen._fetchStats error: $e');
    } catch (e) {
      debugPrint('HomeScreen._fetchStats error: $e');
    }
  }

  /// Fetch captain profile from the backend API (replaces old Firestore stream).
  Future<void> _fetchProfile() async {
    try {
      final result = await ApiService.instance.getProfile();
      if (!mounted) return;
      final captainData = result['captain'] as Map<String, dynamic>?;
      if (captainData == null) return;
      final uid = AuthService.instance.currentUser?.uid ?? '';
      final profile = DriverProfile(
        uid: captainData['firebaseUid'] as String? ?? uid,
        name: captainData['name'] as String? ?? '',
        phone: captainData['phone'] as String? ?? '',
        photoUrl: captainData['photoUrl'] as String?,
        carPhotoUrl: captainData['carPhotoUrl'] as String?,
        nationalId: null,
        idCardUrl: captainData['idCardUrl'] as String?,
        idCardBackUrl: captainData['idCardBackUrl'] as String?,
        vehicleType: captainData['vehicleType'] as String? ?? '',
        vehicleModel: captainData['vehicleModel'] as String? ?? '',
        vehicleColor: captainData['vehicleColor'] as String? ?? '',
        vehicleNumber: captainData['vehicleNumber'] as String? ?? '',
        licenseUrl: captainData['licenseUrl'] as String?,
        licenseBackUrl: captainData['licenseBackUrl'] as String?,
        licenseNumber: captainData['licenseNumber'] as String?,
        insuranceUrl: captainData['insuranceUrl'] as String?,
        criminalRecordUrl: captainData['criminalRecordUrl'] as String?,
        drugTestUrl: captainData['drugTestUrl'] as String?,
        documentsGraceEndsAt: null,
        isBanned: false,
        banUntil: null,
        rating: (captainData['rating'] as num?)?.toDouble(),
        createdAt: captainData['createdAt'] != null
            ? DateTime.parse(captainData['createdAt'] as String)
            : DateTime.now(),
        updatedAt: captainData['updatedAt'] != null
            ? DateTime.parse(captainData['updatedAt'] as String)
            : DateTime.now(),
      );
      setState(() => _profile = profile);
      if (profile.isBanned && _isOnline) {
        _forceOfflineForBan();
      }
    } catch (_) {
      // Profile fetch failed silently; _profile stays null.
    }
  }

  // ──────────────────────────────────────────────────────
  // Periodic location upload (every 15 s while online)
  // ──────────────────────────────────────────────────────

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _uploadCurrentPosition(),
    );
    // Upload immediately on start
    _uploadCurrentPosition();
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // ──────────────────────────────────────────────────────
  // Phase 1: Ride request handling (placeholder for Phase 2)
  // ──────────────────────────────────────────────────────

  // ──────────────────────────────────────────────────────
  // Phase 2: Ride lifecycle — wired to the real backend (ApiService)
  // ──────────────────────────────────────────────────────

  /// قبول طلب رحلة وارد — مُشغّل فقط (Trigger).
  /// الـ Stream هو المسؤول عن تحديث الـ UI عند نجاح القبول (status → accepted).
  Future<void> _acceptRide(RideModel ride) async {
    if (!mounted) return;
    // أوقف تنبيه الرحلة المتكرر فوراً بمجرد تفاعل الكابتن
    await SoundService.instance.stopAlert();
    // 1. إظهار مؤشر تحميل يمنع الضغط المزدوج
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // 2. استدعاء الباك إند (تُرجع true عند النجاح، false عند الفشل)
    final success = await ApiService.instance.acceptRide(ride.id);

    // 3. إخفاء مؤشر التحميل
    if (mounted) Navigator.pop(context);

    if (!success && mounted) {
      // فشل القبول (كابتن آخر التقطها، أو العميل ألغاها)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'عفواً، لم نتمكن من قبول الطلب (ربما تم قبوله من كابتن آخر).',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // نجح القبول: ابدأ تتبّع حالة هذه الرحلة المُقبولة فقط عبر مستندها الخاص
    // في Firestore (rides/{rideId}) — لا علاقة للمستمع العام المُعطّل.
    RealtimeService.instance.stopRideStatusListener();
    RealtimeService.instance.startRideStatusListenerById(ride.id);
    _activeTripId = ride.id;
    // ملاحظة: لا نحدّث الحالة هنا — الـ Stream سيتلقى "accepted" ويعرض TripStatusCard.
  }

  /// رفض طلب الرحلة (يدوياً أو بانتهاء العدّاد) — حدث لحظي لا يُعاد بثّه،
  /// لذا نكتفي بإخفاء الكارت محلياً وإيقاف الصوت. لا حاجة لإبلاغ الباك إند.
  void _rejectRide() {
    if (_currentRideRequest == null) return;
    // أوقف تنبيه الرحلة المتكرر فوراً بمجرد تفاعل الكابتن
    SoundService.instance.stopAlert();
    // لا نوقف مستمع الحالة لأنه لا يُستدعى إلا بعد القبول الفعلي.
    _activeTripId = null;
    setState(() => _currentRideRequest = null);
  }

  /// وصول الكابتن لنقطة الالتقاط — مُشغّل فقط (Trigger).
  /// الـ Stream هو المسؤول عن تحديث الـ UI (status → arrived).
  Future<void> _arriveRide(RideModel ride) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await ApiService.instance.arriveRide(ride.id);

    if (mounted) Navigator.pop(context);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تأكيد الوصول، حاول مرة أخرى.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
    // الـ Stream سيتلقى "arrived" ويحدّث الـ UI تلقائياً.
  }

  /// بدء الرحلة عند ركوب العميل — مُشغّل فقط (Trigger).
  /// الـ Stream هو المسؤول عن تحديث الـ UI (status → started).
  Future<void> _startRide(RideModel ride) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await ApiService.instance.startRide(ride.id);

    if (mounted) Navigator.pop(context);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر بدء الرحلة، حاول مرة أخرى.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
    // الـ Stream سيتلقى "started" ويحدّث الـ UI تلقائياً.
  }

  /// إنهاء الرحلة عند الوصول للوجهة — مُشغّل فقط (Trigger).
  /// الـ Stream هو المسؤول عن تصفير الكارت + إظهار رسالة النجاح (status → completed).
  Future<void> _completeRide(RideModel ride) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await ApiService.instance.completeRide(ride.id);

    if (mounted) Navigator.pop(context);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إنهاء الرحلة، حاول مرة أخرى.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
    // الـ Stream سيتلقى "completed" ويصفّر الكارت + يظهر رسالة النجاح.
  }

  /// فتح شاشة المحادثة الريل تايم مع الراكب أثناء الرحلة النشطة.
  /// الغرفة تُنشأ في Firestore عند قبول الرحلة (من الباك إند)،
  /// ومعرّفها = معرّف الرحلة، والطرف الآخر = riderId.
  void _openChat(RideModel ride) {
    if (!mounted) return;
    final riderId = ride.riderId;
    if (riderId == null || riderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح المحادثة: بيانات الراكب غير متوفرة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      RouteTransitions.slideUp(
        ChatScreen(
          rideId: ride.id,
          riderId: riderId,
          riderName: ride.riderName ?? 'الراكب',
        ),
      ),
    );
  }

  Future<void> _uploadCurrentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _dbService.updateCaptainStatus(
        online: _isOnline,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      // إرسال الموقع للباك إند عبر السوكيت لحظياً
      SocketService().emitLocation(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      // Silent — location upload is best-effort
    }
  }

  /// Toggle the ride-alert sound on/off from the waiting card.
  void _toggleSound() {
    if (!mounted) return;
    setState(() => _soundEnabled = !_soundEnabled);
    if (_soundEnabled) {
      SoundService.instance.playRideAlert(duration: const Duration(seconds: 1));
    } else {
      SoundService.instance.stopTripAlert();
    }
  }

  Future<void> _toggleOnlineStatus() async {
    final newValue = !_isOnline;

    // Guard: cannot go offline during an active trip
    if (!newValue && _activeTripId != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن الإيقاف أثناء رحلة نشطة'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    // Guard: cannot go online while banned for missing documents
    if (newValue) {
      if (_profile?.compliance(DateTime.now()) == DocumentCompliance.banned) {
        _showBannedDialog();
        return;
      }
    }

    // Guard: need location permission to go online
    if (!_locationGranted && newValue) {
      await _checkLocationPermission();
      if (!_locationGranted) return;
    }

    // Show loading state inside the toggle button
    setState(() => _isToggling = true);

    // 1. مزامنة الحالة مع الباك إند أولاً (قبل أي تغيير محلي)
    final backendOk = await ApiService.instance.toggleAvailability(newValue);
    if (!backendOk) {
      setState(() => _isToggling = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر مزامنة حالة التوافر مع السيرفر، حاول مرة أخرى'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return; // لا نغيّر الحالة محلياً عند الفشل
    }

    // 2. نجحت المزامنة → حدّث الواجهة محلياً
    setState(() {
      _isOnline = newValue;
      _isToggling = false;
    });

    // Start/stop periodic location uploads
    if (newValue) {
      _startLocationUpdates();
      // تهيئة اتصال السوكيت لبث الموقع والبيانات الحية
      final uid = AuthService.instance.currentUser?.uid;
      // أعد تحميل التوكن من التخزين المحلي تحسباً لكونه فارغاً في الذاكرة
      // (مثلاً بعد إعادة تشغيل التطبيق) قبل تمريره للسوكيت.
      await ApiService.instance.loadToken();
      final token = ApiService.instance.getToken();
      if (uid != null && token != null) {
        SocketService().initSocket(uid, token);
      }
    } else {
      _stopLocationUpdates();
      // قطع اتصال السوكيت عند تحويل الكابتن إلى Offline
      SocketService().disconnect();
      // أوقف الاستماع لأي رحلة نشطة وأزل الطلب/الرحلة المعروضة
      RealtimeService.instance.stopRideStatusListener();
      _activeTripId = null;
      if (_currentRideRequest != null) {
        setState(() => _currentRideRequest = null);
      }
    }
  }

  // ══════════════════════════════════════════════════════
  // MATERIAL 3 BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.primaryBg,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeContent(),
            const TripsScreen(),
            const WalletScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── Document compliance: ban enforcement helpers ──

  Future<void> _forceOfflineForBan() async {
    if (!mounted) return;
    setState(() => _isOnline = false);
    _stopLocationUpdates();
    // قطع اتصال السوكيت عند الإيقاف القسري للحظر
    SocketService().disconnect();
    try {
      await _dbService.updateCaptainStatus(
        online: false,
        latitude: null,
        longitude: null,
      );
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حظرك مؤقتاً لعدم رفع المستندات المطلوبة'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showBannedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حساب محظور مؤقتاً'),
        content: const Text(
          'لم يتم رفع المستندات المطلوبة (الفيش الجنائى وتحليل المخدرات) '
          'خلال المهلة المحددة. يرجى رفعها الآن لرفع الحظر.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(profile: _profile),
                ),
              );
            },
            child: const Text('رفع المستندات'),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceBanner() {
    final profile = _profile;
    if (profile == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final status = profile.compliance(now);
    if (status == DocumentCompliance.submitted) return const SizedBox.shrink();
    if (status == DocumentCompliance.banned) {
      final until = profile.banUntil;
      final txt = until != null
          ? 'تم حظرك لعدم رفع المستندات المطلوبة (حتى ${_fmtDate(until)})'
          : 'تم حظرك لعدم رفع المستندات المطلوبة';
      return _complianceBannerTile(txt, AppColors.error);
    }
    final daysLeft = profile.daysLeftInGrace(now);
    if (daysLeft <= 7) {
      return _complianceBannerTile(
        'متبقٍ $daysLeft يوم لرفع المستندات قبل الحظر',
        AppColors.warning,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _complianceBannerTile(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.labelSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Widget _buildHomeContent() {
    return Stack(
      children: [
        // ── 1. Full-screen map (always visible) ───────────
        Positioned.fill(
          child: HomeMapWidget(
            mapController: mapController,
            locationGranted: _locationGranted,
            onMapReady: (ready) {
              setState(() => _mapReady = ready);
              if (ready) _enableMapTracking();
            },
          ),
        ),

        // ── 2. Offline gradient scrim ─────────────────────
        if (!_isOnline) _buildOfflineScrim(),

        // ── 3. Floating top row: notifications + online toggle ──
        Positioned(
          top: 48,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // جرس الإشعارات (يمين حسب اتجاه RTL)
              _buildFloatingActionButton(
                icon: Icons.notifications_outlined,
                label: 'الإشعارات',
                onTap: () => Navigator.push(
                  context,
                  RouteTransitions.slideUp(const NotificationsScreen()),
                ),
              ),
              // زر الأونلاين / الأوفلاين (يسار حسب اتجاه RTL)
              if (_currentRideRequest == null)
                OnlineToggleButton(
                  isOnline: _isOnline,
                  hasActiveTrip: _activeTripId != null,
                  isLoading: _isToggling,
                  onToggle: (newValue) => _toggleOnlineStatus(),
                ),
            ],
          ),
        ),
        Positioned(
          top: 112,
          left: 16,
          right: 16,
          child: _buildComplianceBanner(),
        ),

        // ── 3b. Stats header bar (earnings, trips, rating) ──
        if (_isOnline)
          Positioned(top: 160, left: 16, right: 16, child: _buildStatsBar()),

        // ── 3c. Empty / Waiting state (online, no active ride) ──
        if (_isOnline && _currentRideRequest == null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: OnlineWaitingCard(
              isSoundEnabled: _soundEnabled,
              onSoundToggle: _toggleSound,
            ),
          ),

        // ── 4. My Location FAB ────────────────────────────
        if (_mapReady && _isOnline)
          Positioned(left: 16, bottom: 24, child: _buildMyLocationButton()),

        // ── 5. بطاقة الرحلة الريل‑تايم (مدفوعة بالـ Stream) ──
        if (_currentRideRequest != null)
          if (_currentRideRequest!.status == RideStatus.pending)
            // طلب جديد بانتظار القبول
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: RideRequestCard(
                pickupAddress: _currentRideRequest!.pickupAddress,
                destinationAddress: _currentRideRequest!.destinationAddress,
                price: _currentRideRequest!.fare?.toStringAsFixed(2),
                riderName: _currentRideRequest!.riderName,
                distance: _currentRideRequest!.distance,
                onAccept: () => _acceptRide(_currentRideRequest!),
                onReject: _rejectRide,
                onExpired: _rejectRide,
              ),
            )
          else if (_currentRideRequest!.status == RideStatus.accepted ||
              _currentRideRequest!.status == RideStatus.arrived ||
              _currentRideRequest!.status == RideStatus.started)
            // رحلة نشطة (مقبولة / وصل الكابتن / قيد التنفيذ)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: TripStatusCard(
                status: _currentRideRequest!.status.name,
                pickupAddress: _currentRideRequest!.pickupAddress,
                destinationAddress: _currentRideRequest!.destinationAddress,
                price: _currentRideRequest!.fare?.toStringAsFixed(2),
                riderName: _currentRideRequest!.riderName,
                distance: _currentRideRequest!.distance,
                etaText: _currentRideRequest!.etaText,
                onMarkArrived: () => _arriveRide(_currentRideRequest!),
                onMarkStarted: () => _startRide(_currentRideRequest!),
                onMarkCompleted: () => _completeRide(_currentRideRequest!),
                onBackToHome: () => setState(() => _currentRideRequest = null),
                onOpenChat: () => _openChat(_currentRideRequest!),
              ),
            ),
      ],
    );
  }

  Widget _buildFloatingActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color backgroundColor = AppColors.card,
    Color iconColor = AppColors.textSecondary,
  }) {
    return Semantics(
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: AppColors.shadowMd,
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Icon(icon, color: iconColor, size: 26),
        ),
      ),
    );
  }

  // ── Stats header bar ────────────────────────────────

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _statItem(
            icon: Icons.account_balance_wallet_outlined,
            label: 'وارد اليوم',
            value: '${_earningsToday.toStringAsFixed(0)} ج.م',
            color: AppColors.success,
          ),
          _divider(),
          _statItem(
            icon: Icons.route_outlined,
            label: 'رحلات اليوم',
            value: '$_tripsToday',
            color: AppColors.primary,
          ),
          _divider(),
          _statItem(
            icon: Icons.star_outline,
            label: 'التقييم',
            value: _rating > 0 ? _rating.toStringAsFixed(1) : '--',
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: AppColors.border);
  }

  /// Light bottom-only overlay to preserve a clear map view.
  Widget _buildOfflineScrim() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppColors.primaryBg.withValues(alpha: 0.85),
              Colors.transparent,
            ],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'أنت غير متصل حالياً',
                  style: AppTextStyles.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// My Location button – centers the map on the user's current position.
  Widget _buildMyLocationButton() {
    return Semantics(
      label: 'تحديد موقعي',
      child: GestureDetector(
        onTap: () async {
          try {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
              ),
            );
            final point = osm.GeoPoint(
              latitude: pos.latitude,
              longitude: pos.longitude,
            );
            await mapController.moveTo(point, animate: true);
            await mapController.setZoom(zoomLevel: 16.0);
            HapticFeedback.mediumImpact();
          } catch (_) {}
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppColors.shadowMd,
          ),
          child: Icon(
            Icons.my_location_rounded,
            color: AppColors.primary,
            size: 26,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BOTTOM NAVIGATION (Material 3 NavigationBar)
  // ══════════════════════════════════════════════════════

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radiusXxl),
          topRight: Radius.circular(AppSpacing.radiusXxl),
        ),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
          HapticFeedback.lightImpact();
        },
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, size: 28),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt_rounded, size: 28),
            label: 'الرحلات',
          ),
          NavigationDestination(
            icon: Icon(Icons.wallet_outlined),
            selectedIcon: Icon(Icons.wallet_rounded, size: 28),
            label: 'المحفظة',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, size: 28),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}
