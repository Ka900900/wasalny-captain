/// Represents a captain's complete profile stored in `captains/{uid}`.
class DriverProfile {
  final String uid;
  final String name;
  final String phone;
  final String? photoUrl;
  final String? carPhotoUrl;
  final String? nationalId;
  final String? idCardUrl;
  final String vehicleType;
  final String vehicleModel;
  final String vehicleColor;
  final String vehicleNumber;
  final String? licenseUrl;
  final String? licenseNumber;
  final String? insuranceUrl;
  final String? criminalRecordUrl;
  final String? drugTestUrl;
  final DateTime? documentsGraceEndsAt;
  final bool isBanned;
  final DateTime? banUntil;
  final double? rating;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriverProfile({
    required this.uid,
    required this.name,
    required this.phone,
    this.photoUrl,
    this.carPhotoUrl,
    this.nationalId,
    this.idCardUrl,
    required this.vehicleType,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.vehicleNumber,
    this.licenseUrl,
    this.licenseNumber,
    this.insuranceUrl,
    this.criminalRecordUrl,
    this.drugTestUrl,
    this.documentsGraceEndsAt,
    this.isBanned = false,
    this.banUntil,
    this.rating,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [DriverProfile] from a Firestore document snapshot.
  factory DriverProfile.fromMap(String uid, Map<String, dynamic> data) {
    return DriverProfile(
      uid: uid,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      carPhotoUrl: data['carPhotoUrl'] as String?,
      nationalId: data['nationalId'] as String?,
      vehicleType: data['vehicleType'] as String? ?? '',
      vehicleModel: data['vehicleModel'] as String? ?? '',
      vehicleColor: data['vehicleColor'] as String? ?? '',
      vehicleNumber: data['vehicleNumber'] as String? ?? '',
      licenseUrl: data['licenseUrl'] as String?,
      licenseNumber: data['licenseNumber'] as String?,
      insuranceUrl: data['insuranceUrl'] as String?,
      criminalRecordUrl: data['criminalRecordUrl'] as String?,
      drugTestUrl: data['drugTestUrl'] as String?,
      documentsGraceEndsAt: (data['documentsGraceEndsAt'] as dynamic)?.toDate(),
      isBanned: data['isBanned'] as bool? ?? false,
      banUntil: (data['banUntil'] as dynamic)?.toDate(),
      idCardUrl: data['idCardUrl'] as String?,
      rating: (data['rating'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this profile to a Map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'carPhotoUrl': carPhotoUrl,
      'nationalId': nationalId,
      'idCardUrl': idCardUrl,
      'vehicleType': vehicleType,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'vehicleNumber': vehicleNumber,
      'licenseUrl': licenseUrl,
      'licenseNumber': licenseNumber,
      'insuranceUrl': insuranceUrl,
      'criminalRecordUrl': criminalRecordUrl,
      'drugTestUrl': drugTestUrl,
      'documentsGraceEndsAt': documentsGraceEndsAt,
      'isBanned': isBanned,
      'banUntil': banUntil,
      'rating': rating,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Returns a copy with the given fields replaced.
  DriverProfile copyWith({
    String? uid,
    String? name,
    String? phone,
    String? photoUrl,
    String? carPhotoUrl,
    String? nationalId,
    String? idCardUrl,
    String? vehicleType,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleNumber,
    String? licenseUrl,
    String? licenseNumber,
    String? insuranceUrl,
    String? criminalRecordUrl,
    String? drugTestUrl,
    DateTime? documentsGraceEndsAt,
    bool? isBanned,
    DateTime? banUntil,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      carPhotoUrl: carPhotoUrl ?? this.carPhotoUrl,
      nationalId: nationalId ?? this.nationalId,
      idCardUrl: idCardUrl ?? this.idCardUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      insuranceUrl: insuranceUrl ?? this.insuranceUrl,
      criminalRecordUrl: criminalRecordUrl ?? this.criminalRecordUrl,
      drugTestUrl: drugTestUrl ?? this.drugTestUrl,
      documentsGraceEndsAt: documentsGraceEndsAt ?? this.documentsGraceEndsAt,
      isBanned: isBanned ?? this.isBanned,
      banUntil: banUntil ?? this.banUntil,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// حالة امتثال الكابتن للمستندات الرسمية المطلوبة
/// (الفيش الجنائى + تحليل المخدرات).
enum DocumentCompliance {
  submitted, // تم رفع المستندان
  grace, // ضمن مهلة الـ30 يوم
  banned, // انتهت المهلة دون رفع → محظور
}

/// دوال مساعدة لحساب حالة المستندات وعرضها في الواجهة.
extension DriverProfileCompliance on DriverProfile {
  /// هل رُفع المستندان المطلوبان؟
  bool get documentsSubmitted =>
      criminalRecordUrl != null && drugTestUrl != null;

  /// نهاية مهلة الـ30 يوم. تُستمد من [createdAt] إن لم تُخزَّن صراحة.
  DateTime get graceEndsAt =>
      documentsGraceEndsAt ?? createdAt.add(const Duration(days: 30));

  /// الأيام المتبقية في المهلة (قد تكون سالبة بعد انتهائها).
  int daysLeftInGrace(DateTime now) => graceEndsAt.difference(now).inDays;

  /// الحالة الفعلية: المعتمدة من حقل [isBanned] (تحدده الدالة السحابية)
  /// أو بحساب محلي فوري حتى تعمل الواجهة قبل تشغيل الدالة.
  DocumentCompliance compliance(DateTime now) {
    if (documentsSubmitted) return DocumentCompliance.submitted;
    if (isBanned || now.isAfter(graceEndsAt)) {
      return DocumentCompliance.banned;
    }
    return DocumentCompliance.grace;
  }
}
