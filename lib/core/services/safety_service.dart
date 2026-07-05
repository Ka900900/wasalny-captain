import 'dart:async';
import 'package:geolocator/geolocator.dart';

import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/repositories/safety_repository.dart';
import 'package:waslny_captain/core/models/safety_models.dart';

/// Centralised service that manages SOS alerts, emergency contacts, and
/// live location sharing.
class SafetyService {
  // ── Singleton ───────────────────────────────────────
  SafetyService._();
  static final SafetyService instance = SafetyService._();

  final SafetyRepository _repo = SafetyRepository.instance;

  // ── Live‑sharing state ──────────────────────────────
  StreamSubscription<Position>? _positionSub;
  Timer? _locationUploadTimer;
  bool _isSharing = false;

  /// Whether the captain is currently sharing their live location.
  bool get isSharing => _isSharing;

  /// Called when sharing state changes.
  void Function(bool isSharing)? onSharingChanged;

  /// Called when a new SOS alert is created.
  void Function(SOSAlert alert)? onSOSTriggered;

  // ────────────────────────────────────────────────────
  // SOS (Emergency Alert)
  // ────────────────────────────────────────────────────

  /// Trigger an SOS alert.
  ///
  /// 1. Gets the current GPS position.
  /// 2. Saves the alert to Firestore.
  /// 3. Starts live location sharing so emergency contacts can track.
  /// 4. Fires the [onSOSTriggered] callback.
  Future<SOSAlert> triggerSOS() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    // Get current position
    double? lat;
    double? lng;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      // Location unavailable — SOS still works without it
    }

    final alert = SOSAlert(
      id: '', // Will be assigned by Firestore
      status: SOSStatus.active,
      latitude: lat,
      longitude: lng,
      createdAt: DateTime.now(),
    );

    // Save to Firestore
    await _repo.createSOSAlert(uid, alert);

    // Automatically start live sharing
    await startLiveSharing(latitude: lat, longitude: lng);

    onSOSTriggered?.call(alert);

    return alert;
  }

  /// Resolve the currently active SOS alert.
  Future<void> resolveSOS() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    // Find the active alert
    final activeAlerts = await _repo.fetchSOSHistory(uid, limit: 1);
    for (final alert in activeAlerts) {
      if (alert.status == SOSStatus.active) {
        await _repo.resolveSOSAlert(uid, alert.id);
      }
    }

    // Stop live sharing
    await stopLiveSharing();
  }

  // ────────────────────────────────────────────────────
  // Live Location Sharing
  // ────────────────────────────────────────────────────

  /// Start sharing the captain's live location to Firestore.
  ///
  /// Optionally [sharedWithId] can be a trip ID or contact ID.
  Future<void> startLiveSharing({
    String? sharedWithId,
    double? latitude,
    double? longitude,
  }) async {
    if (_isSharing) return;

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    // Mark sharing as active in Firestore
    await _repo.startSharing(
      uid,
      sharedWithId: sharedWithId,
      latitude: latitude,
      longitude: longitude,
    );

    _isSharing = true;
    onSharingChanged?.call(true);

    // Start GPS tracking
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // every 5 metres
      ),
    ).listen((pos) {
      _repo.updateSharedLocation(
        uid,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    });

    // Fallback timer
    _locationUploadTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!_isSharing) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        await _repo.updateSharedLocation(
          uid,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      } catch (_) {}
    });
  }

  /// Stop sharing the captain's live location.
  Future<void> stopLiveSharing() async {
    if (!_isSharing) return;

    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      await _repo.stopSharing(uid);
    }

    _positionSub?.cancel();
    _positionSub = null;
    _locationUploadTimer?.cancel();
    _locationUploadTimer = null;
    _isSharing = false;
    onSharingChanged?.call(false);
  }

  /// Dispose the service. Call on logout.
  void dispose() {
    _positionSub?.cancel();
    _locationUploadTimer?.cancel();
    _isSharing = false;
  }
}
