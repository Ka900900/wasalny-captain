/// Represents a captain's complete profile stored in `captains/{uid}`.
class DriverProfile {
  final String uid;
  final String name;
  final String phone;
  final String? photoUrl;
  final String? nationalId;
  final String? idCardUrl;
  final String vehicleType;
  final String vehicleModel;
  final String vehicleColor;
  final String vehicleNumber;
  final String? licenseUrl;
  final String? licenseNumber;
  final String? insuranceUrl;
  final double? rating;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriverProfile({
    required this.uid,
    required this.name,
    required this.phone,
    this.photoUrl,
    this.nationalId,
    this.idCardUrl,
    required this.vehicleType,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.vehicleNumber,
    this.licenseUrl,
    this.licenseNumber,
    this.insuranceUrl,
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
      nationalId: data['nationalId'] as String?,
      vehicleType: data['vehicleType'] as String? ?? '',
      vehicleModel: data['vehicleModel'] as String? ?? '',
      vehicleColor: data['vehicleColor'] as String? ?? '',
      vehicleNumber: data['vehicleNumber'] as String? ?? '',
      licenseUrl: data['licenseUrl'] as String?,
      licenseNumber: data['licenseNumber'] as String?,
      insuranceUrl: data['insuranceUrl'] as String?,
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
      'nationalId': nationalId,
      'idCardUrl': idCardUrl,
      'vehicleType': vehicleType,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'vehicleNumber': vehicleNumber,
      'licenseUrl': licenseUrl,
      'licenseNumber': licenseNumber,
      'insuranceUrl': insuranceUrl,
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
    String? nationalId,
    String? idCardUrl,
    String? vehicleType,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleNumber,
    String? licenseUrl,
    String? licenseNumber,
    String? insuranceUrl,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      nationalId: nationalId ?? this.nationalId,
      idCardUrl: idCardUrl ?? this.idCardUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      insuranceUrl: insuranceUrl ?? this.insuranceUrl,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
