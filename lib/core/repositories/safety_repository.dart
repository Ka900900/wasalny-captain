import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:waslny_captain/core/models/safety_models.dart';

/// Repository that manages safety‑related data in Firestore.
///
/// Data is organised as:
/// - `drivers/{uid}/emergencyContacts/{contactId}` → saved contacts
/// - `drivers/{uid}/sos/{alertId}`                 → SOS alert history
/// - `drivers/{uid}/liveSharing`                   → live‑sharing state doc
class SafetyRepository {
  SafetyRepository._();
  static final SafetyRepository instance = SafetyRepository._();

  // ──────────────────────────────────────────────────────
  // Firestore helpers
  // ──────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _driverRef(String uid) =>
      FirebaseFirestore.instance.collection('drivers').doc(uid);

  CollectionReference<Map<String, dynamic>> _contactsRef(String uid) =>
      _driverRef(uid).collection('emergencyContacts');

  CollectionReference<Map<String, dynamic>> _sosRef(String uid) =>
      _driverRef(uid).collection('sos');

  DocumentReference<Map<String, dynamic>> _sharingRef(String uid) =>
      _driverRef(uid).collection('liveSharing').doc('state');

  // ──────────────────────────────────────────────────────
  // Emergency Contacts
  // ──────────────────────────────────────────────────────

  /// Fetch all emergency contacts for the driver.
  Future<List<EmergencyContact>> fetchEmergencyContacts(String uid) async {
    try {
      final snap =
          await _contactsRef(uid).orderBy('createdAt', descending: false).get();
      return snap.docs
          .map((d) => EmergencyContact.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Stream emergency contacts in real time.
  Stream<List<EmergencyContact>> streamEmergencyContacts(String uid) {
    return _contactsRef(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => EmergencyContact.fromMap(d.id, d.data()))
            .toList());
  }

  /// Add a new emergency contact.
  Future<void> addEmergencyContact(
    String uid,
    EmergencyContact contact,
  ) async {
    await _contactsRef(uid).add(contact.toMap());
  }

  /// Update an existing emergency contact.
  Future<void> updateEmergencyContact(
    String uid,
    EmergencyContact contact,
  ) async {
    await _contactsRef(uid).doc(contact.id).set(contact.toMap());
  }

  /// Delete an emergency contact.
  Future<void> deleteEmergencyContact(String uid, String contactId) async {
    await _contactsRef(uid).doc(contactId).delete();
  }

  // ──────────────────────────────────────────────────────
  // SOS Alerts
  // ──────────────────────────────────────────────────────

  /// Create a new SOS alert.
  Future<void> createSOSAlert(String uid, SOSAlert alert) async {
    await _sosRef(uid).add(alert.toMap());
  }

  /// Mark an SOS alert as resolved.
  Future<void> resolveSOSAlert(String uid, String alertId) async {
    await _sosRef(uid).doc(alertId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch SOS alert history, newest first.
  Future<List<SOSAlert>> fetchSOSHistory(
    String uid, {
    int limit = 20,
  }) async {
    try {
      final snap = await _sosRef(uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => SOSAlert.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Stream SOS alerts in real time (mostly for checking active status).
  Stream<List<SOSAlert>> streamActiveSOS(String uid) {
    return _sosRef(uid)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SOSAlert.fromMap(d.id, d.data()))
            .toList());
  }

  // ──────────────────────────────────────────────────────
  // Live Location Sharing
  // ──────────────────────────────────────────────────────

  /// Start sharing the driver's live location.
  /// [sharedWithId] can be a trip ID or contact ID.
  Future<void> startSharing(
    String uid, {
    String? sharedWithId,
    double? latitude,
    double? longitude,
  }) async {
    await _sharingRef(uid).set({
      'isSharing': true,
      'sharedWithId': sharedWithId,
      'startedAt': FieldValue.serverTimestamp(),
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Stop sharing the driver's live location.
  Future<void> stopSharing(String uid) async {
    await _sharingRef(uid).update({
      'isSharing': false,
    });
  }

  /// Update the current location while sharing is active.
  Future<void> updateSharedLocation(
    String uid, {
    required double latitude,
    required double longitude,
  }) async {
    await _sharingRef(uid).update({
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Fetch the current live‑sharing state.
  Future<LiveSharingState?> fetchSharingState(String uid) async {
    try {
      final doc = await _sharingRef(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return LiveSharingState.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Stream the live‑sharing state in real time.
  Stream<LiveSharingState?> streamSharingState(String uid) {
    return _sharingRef(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return LiveSharingState.fromMap(doc.data()!);
    });
  }
}
