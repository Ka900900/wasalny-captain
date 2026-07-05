import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waslny_captain/core/models/captain_model.dart' as model;

/// Service for all Firestore read/write operations.
///
/// Instantiate normally: `final db = DatabaseService();`
/// All methods throw meaningful exceptions on failure.
class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DatabaseService();

  // دالة لجلب بيانات الكابتن الحالي بناءً على تسجيل دخوله
  Stream<model.CaptainModel?> get captainDataStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(null);
    }
    return _db.collection('captains').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (snapshot.exists && data != null) {
        return model.CaptainModel.fromMap(data, snapshot.id);
      }
      return null;
    });
  }

  // دالة لتحديث بيانات الحساب الشخصي (الاسم والهاتف)
  Future<void> updatePersonalInfo(String name, String phone) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'لا يوجد مستخدم',
      );
    }
    await _db.collection('captains').doc(uid).update({
      'name': name,
      'phone': phone,
    });
  }

  // دالة لتحديث بيانات المركبة
  Future<void> updateVehicleInfo(
    String model,
    String plate,
    String color,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'لا يوجد مستخدم',
      );
    }
    await _db.collection('captains').doc(uid).update({
      'carModel': model,
      'carPlate': plate,
      'carColor': color,
    });
  }

  /// Update captain online/offline status in Firestore.
  ///
  /// Fields:
  /// - `online` — whether the captain is accepting rides
  /// - `available` — mirrored from [online]
  /// - `latitude` / `longitude` — last known position (optional)
  /// - `lastSeen` — server timestamp
  /// - `updatedAt` — server timestamp
  ///
  /// Throws a [FirebaseException] if the user is not authenticated or the
  /// write fails.
  Future<void> updateCaptainStatus({
    required bool online,
    double? latitude,
    double? longitude,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'لا يوجد مستخدم مسجل دخوله حالياً',
      );
    }

    final Map<String, dynamic> data = {
      'isOnline': online,
      'available': online,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    };

    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;

    await _db
        .collection('captains')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }
}
