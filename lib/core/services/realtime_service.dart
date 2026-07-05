import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_service.dart';

/// Centralised service that manages all real‑time Firestore listeners
/// and GPS‑based events used by the captain app.
///
/// Handles four event categories:
///  1. **Driver Location Updates**  – GPS → `drivers/{uid}.location`
///  2. **Ride Status Updates**     – listens to a single ride document
///  3. **New Ride Requests**       – listens to `rides` where status == 'pending'
///  4. **ETA Updates**             – calculates ETA from driver → pickup & writes to Firestore
///
/// ## Usage
/// ```dart
/// final rt = RealtimeService.instance;
/// rt.onNewRideRequest = (ride) { … };
/// rt.startRideListener();
/// ```
class RealtimeService {
  // ── Singleton ───────────────────────────────────────
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  // ────────────────────────────────────────────────────
  // 1. Driver Location Updates
  // ────────────────────────────────────────────────────

  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationUploadTimer;
  Position? _lastPosition;

  /// Called every time a new GPS position is received.
  void Function(Position position)? onDriverLocationChanged;

  /// Start streaming GPS position and uploading to Firestore every ~10 m.
  void startGpsTracking() {
    try {
      // Real‑time stream when the device moves
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // every 10 metres
        ),
      ).listen(_onPosition, onError: (_) {});
    } catch (_) {
      // Location not available on this platform (web without HTTPS, etc.)
    }

    // Fallback periodic upload when the stream is silent
    try {
      _locationUploadTimer = Timer.periodic(const Duration(seconds: 30), (
        _,
      ) async {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          await _uploadLocation(pos);
        } catch (_) {}
      });
    } catch (_) {}
  }

  /// Stop GPS tracking and mark driver offline in Firestore.
  void stopGpsTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationUploadTimer?.cancel();
    _locationUploadTimer = null;
    _lastPosition = null;

    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('drivers').doc(uid).update({
        'isOnline': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _onPosition(Position pos) {
    _lastPosition = pos;
    onDriverLocationChanged?.call(pos);
    _uploadLocation(pos);
  }

  Future<void> _uploadLocation(Position pos) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'location': GeoPoint(pos.latitude, pos.longitude),
        'isOnline': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────
  // 2. New Ride Requests
  // ────────────────────────────────────────────────────

  StreamSubscription<QuerySnapshot>? _pendingRidesSubscription;

  /// Called when a new pending ride arrives (first doc in snapshot).
  void Function(DocumentSnapshot ride)? onNewRideRequest;

  /// Called when the pending‑rides snapshot becomes empty.
  void Function()? onNoPendingRides;

  /// Start listening to the `rides` collection for documents with
  /// `status == 'pending'`.
  void startRideListener() {
    _pendingRidesSubscription = FirebaseFirestore.instance
        .collection('rides')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            onNewRideRequest?.call(snapshot.docs.first);
          } else {
            onNoPendingRides?.call();
          }
        });
  }

  void stopRideListener() {
    _pendingRidesSubscription?.cancel();
    _pendingRidesSubscription = null;
  }

  // ────────────────────────────────────────────────────
  // 3. Ride Status Updates
  // ────────────────────────────────────────────────────

  StreamSubscription<DocumentSnapshot>? _activeRideSubscription;

  /// Called when the ride document's `status` field changes.
  /// The argument is the new status string.
  void Function(String status)? onRideStatusChanged;

  /// Called when the ride was cancelled by the passenger.
  void Function()? onRideCancelled;

  /// Start listening to a specific ride document for status changes.
  void startRideStatusListener(DocumentReference rideRef) {
    _activeRideSubscription = rideRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        onRideCancelled?.call();
        return;
      }
      final status = snapshot['status'] as String?;
      if (status == 'cancelled' || status == 'cancelled_by_passenger') {
        onRideCancelled?.call();
      } else if (status != null) {
        onRideStatusChanged?.call(status);
      }
    });
  }

  void stopRideStatusListener() {
    _activeRideSubscription?.cancel();
    _activeRideSubscription = null;
  }

  // ────────────────────────────────────────────────────
  // 4. ETA Updates
  // ────────────────────────────────────────────────────

  Timer? _etaTimer;
  GeoPoint? _etaPickupLocation;
  String? _etaRideId;

  /// Called when a new ETA string is calculated.
  void Function(String eta, double minutes)? onEtaUpdated;

  /// Start periodic ETA calculation (every 20 s) from the driver's
  /// current position to [pickupLocation].  Writes the result to
  /// `rides/{rideId}.driverEta` in Firestore.
  void startEtaUpdates({
    required String rideId,
    required GeoPoint pickupLocation,
  }) {
    _etaRideId = rideId;
    _etaPickupLocation = pickupLocation;
    _calculateAndUploadEta(); // immediate first calculation
    _etaTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _calculateAndUploadEta(),
    );
  }

  void stopEtaUpdates() {
    _etaTimer?.cancel();
    _etaTimer = null;
    _etaRideId = null;
    _etaPickupLocation = null;
  }

  Future<void> _calculateAndUploadEta() async {
    final pos = _lastPosition;
    final pickup = _etaPickupLocation;
    final rideId = _etaRideId;
    if (pos == null || pickup == null || rideId == null) return;

    try {
      // Distance in metres
      final meters = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        pickup.latitude,
        pickup.longitude,
      );

      // Assume average city speed of 8.33 m/s (≈30 km/h)
      const double avgSpeedMps = 8.33;
      final double seconds = meters / avgSpeedMps;
      final double minutes = seconds / 60.0;

      String etaText;
      if (minutes < 1) {
        etaText = 'أقل من دقيقة';
      } else if (minutes < 60) {
        etaText = '${minutes.round()} دقيقة';
      } else {
        final hours = minutes / 60;
        etaText = '${hours.toStringAsFixed(1)} ساعة';
      }

      // Write to Firestore so the passenger can read it
      await FirebaseFirestore.instance.collection('rides').doc(rideId).set({
        'driverEta': etaText,
        'driverEtaMinutes': minutes,
        'driverEtaUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      onEtaUpdated?.call(etaText, minutes);
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────
  // Clean‑up
  // ────────────────────────────────────────────────────

  /// Stop **all** listeners, timers, and subscriptions.
  void dispose() {
    stopGpsTracking();
    stopRideListener();
    stopRideStatusListener();
    stopEtaUpdates();
  }
}
