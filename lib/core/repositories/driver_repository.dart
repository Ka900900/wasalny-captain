import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:waslny_captain/core/models/driver_profile.dart';

/// Repository that manages captain profile data in Firestore.
///
/// Images are no longer uploaded directly from the app. They are sent to the
/// Railway backend (multipart/form-data, JWT-protected) which uploads them to
/// Cloudinary and persists the URLs. The resulting URLs are written here to
/// the appropriate Firestore fields (photoUrl / licenseUrl / idCardUrl).
class DriverRepository {
  DriverRepository._();
  static final DriverRepository instance = DriverRepository._();

  /// Firestore collection reference.
  static const String _collection = 'captains';

  // ──────────────────────────────────────────────
  // Firestore helpers
  // ──────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _docRef(String uid) =>
      FirebaseFirestore.instance.collection(_collection).doc(uid);

  // ──────────────────────────────────────────────
  // Queries
  // ──────────────────────────────────────────────

  /// Fetches the driver profile once.
  Future<DriverProfile?> getProfile(String uid) async {
    final doc = await _docRef(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return DriverProfile.fromMap(uid, doc.data()!);
  }

  /// Returns a real-time stream of the driver profile.
  Stream<DriverProfile?> streamProfile(String uid) {
    return _docRef(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return DriverProfile.fromMap(uid, snap.data()!);
    });
  }

  // ──────────────────────────────────────────────
  // Mutations
  // ──────────────────────────────────────────────

  /// Creates a new driver profile document in Firestore.
  Future<void> createProfile(DriverProfile profile) async {
    await _docRef(profile.uid).set(profile.toMap());
  }

  /// Updates the driver profile document in Firestore.
  ///
  /// Only the fields present in [updates] are changed; the [updatedAt]
  /// timestamp is always refreshed.
  Future<void> updateProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _docRef(uid).update(updates);
  }

  /// Saves (creates or merges) the driver profile.  If the document already
  /// exists only the supplied fields are overwritten.
  Future<void> saveProfile(DriverProfile profile) async {
    await _docRef(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }
}
