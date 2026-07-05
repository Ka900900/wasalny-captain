import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'package:waslny_captain/core/models/driver_profile.dart';
import 'package:waslny_captain/core/services/auth_service.dart';

/// Repository that manages captain profile data in Firestore and images in
/// Firebase Storage.
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

  // ──────────────────────────────────────────────
  // Image upload (Firebase Storage)
  // ──────────────────────────────────────────────

  /// Picks an image from the device, uploads it to Firebase Storage and
  /// returns the download URL.
  ///
  /// [folder] is a path prefix such as `profiles/photos` or `profiles/licenses`.
  Future<String?> uploadImage({
    required String folder,
    ImageSource source = ImageSource.gallery,
  }) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return null;

    // Pick image
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;

    // Upload to Firebase Storage
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final Reference ref = FirebaseStorage.instance.ref().child(
      'captains/$uid/$folder/$fileName',
    );

    await ref.putData(await picked.readAsBytes());
    return await ref.getDownloadURL();
  }

  /// Uploads an already-picked file to Firebase Storage.
  Future<String?> uploadPickedFile({
    required String filePath,
    required String folder,
  }) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return null;

    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final Reference ref = FirebaseStorage.instance.ref().child(
      'captains/$uid/$folder/$fileName',
    );

    await ref.putFile(File(filePath));
    return await ref.getDownloadURL();
  }
}
