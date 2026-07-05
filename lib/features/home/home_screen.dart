import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:geolocator/geolocator.dart';

import 'package:waslny_captain/core/design_system/design_system.dart';
import 'package:waslny_captain/core/services/database_service.dart';
import 'package:waslny_captain/core/widgets/route_transitions.dart';
import 'package:waslny_captain/features/trips/trips_screen.dart';
import 'package:waslny_captain/features/wallet/wallet_screen.dart';
import 'package:waslny_captain/features/profile/profile_screen.dart';
import 'package:waslny_captain/features/notifications/notifications_screen.dart';
import 'package:waslny_captain/features/safety/safety_screen.dart';

import 'widgets/home_map_widget.dart';
import 'widgets/home_app_bar.dart';

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
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _locationTimer = null;
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
    } catch (_) {
      // Silent — location upload is best-effort
    }
  }

  // ──────────────────────────────────────────────────────
  // Online/Offline toggle logic
  // ──────────────────────────────────────────────────────

  Future<void> _toggleOnlineStatus() async {
    final newValue = !_isOnline;
    final previousValue = _isOnline;

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

    // Guard: need location permission to go online
    if (!_locationGranted && newValue) {
      await _checkLocationPermission();
      if (!_locationGranted) return;
    }

    // Optimistic UI update
    setState(() => _isOnline = newValue);

    try {
      // Get current position to send with status
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      } catch (_) {}

      await _dbService.updateCaptainStatus(
        online: newValue,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );

      // Start/stop periodic location uploads
      if (newValue) {
        _startLocationUpdates();
      } else {
        _stopLocationUpdates();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'تم التفعيل بنجاح' : 'تم الإيقاف بنجاح'),
            backgroundColor: newValue ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      debugPrint('updateCaptainStatus error: $e');

      // Rollback UI to previous state on failure
      setState(() => _isOnline = previousValue);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديث حالة التواجد، حاول مرة أخرى'),
            backgroundColor: AppColors.error,
          ),
        );
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

        // ── 3. Top bar + status badge in a SafeArea ───────
        // The status badge is the ONLY online/offline controller.
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: HomeAppBar(
                        onProfileTap: () => Navigator.push(
                          context,
                          RouteTransitions.slideUp(const ProfileScreen()),
                        ),
                        onNotificationsTap: () => Navigator.push(
                          context,
                          RouteTransitions.slideUp(const NotificationsScreen()),
                        ),
                        onSafetyTap: () => Navigator.push(
                          context,
                          RouteTransitions.slideUp(const SafetyScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        // ── 4. My Location FAB ────────────────────────────
        if (_mapReady && _isOnline)
          Positioned(left: 16, bottom: 24, child: _buildMyLocationButton()),
      ],
    );
  }

  /// Status badge — the ONLY online/offline controller.
  Widget _buildStatusBadge() {
    return GestureDetector(
      onTap: _toggleOnlineStatus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _isOnline ? AppColors.primaryContainer : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: _isOnline ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow: _isOnline ? AppColors.shadowPrimary : AppColors.shadowSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: _isOnline ? AppColors.primary : AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _isOnline ? 'متصل' : 'غير متصل',
                key: ValueKey(_isOnline),
                style: AppTextStyles.labelSmall?.copyWith(
                  color: _isOnline ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
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
