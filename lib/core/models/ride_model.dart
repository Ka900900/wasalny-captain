import 'package:cloud_firestore/cloud_firestore.dart';

/// حالات الرحلة المدعومة (متطابقة مع Firestore + trip_status_card)
enum RideStatus {
  pending, // في انتظار قبول الكابتن
  accepted, // الكابتن قبل الرحلة (متجه للركوب)
  arrived, // الكابتن وصل لنقطة الالتقاط
  started, // بدأت الرحلة (متجه للوجهة)
  completed, // انتهت الرحلة
  cancelled, // ملغاة
}

/// نموذج الرحلة (RideModel) — يمثّل طلب رحلة جديد أو رحلة نشطة.
///
/// يُستخدم في:
/// - [RideRequestCard] (عند وصول طلب جديد)
/// - [TripStatusCard] (أثناء تنفيذ الرحلة)
/// - [RealtimeService] (يُنشأ من [DocumentSnapshot] لـ `rides` collection)
class RideModel {
  final String id;
  final String? riderId;
  final String? riderName;
  final String? pickupAddress;
  final String? destinationAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? fare;
  final String? vehicleType;
  final RideStatus status;
  final String? distance; // نص مثل "3.2 كم"
  final String? etaText; // نص مثل "5 دقائق"
  final DateTime? createdAt;

  const RideModel({
    required this.id,
    this.riderId,
    this.riderName,
    this.pickupAddress,
    this.destinationAddress,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.fare,
    this.vehicleType,
    this.status = RideStatus.pending,
    this.distance,
    this.etaText,
    this.createdAt,
  });

  /// نسخة معدّلة من النموذج (تُستخدم لتحديث الحالة محلياً)
  RideModel copyWith({
    String? id,
    String? riderId,
    String? riderName,
    String? pickupAddress,
    String? destinationAddress,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    double? fare,
    String? vehicleType,
    RideStatus? status,
    String? distance,
    String? etaText,
    DateTime? createdAt,
  }) {
    return RideModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      fare: fare ?? this.fare,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      distance: distance ?? this.distance,
      etaText: etaText ?? this.etaText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// إنشاء من DocumentSnapshot (كما يُرجع من RealtimeService)
  factory RideModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RideModel(
      id: doc.id,
      riderId: data['riderId'] as String?,
      riderName: data['riderName'] as String?,
      pickupAddress: data['pickupAddress'] as String?,
      destinationAddress: data['destinationAddress'] as String?,
      pickupLat: (data['pickupLat'] as num?)?.toDouble(),
      pickupLng: (data['pickupLng'] as num?)?.toDouble(),
      destinationLat: (data['destinationLat'] as num?)?.toDouble(),
      destinationLng: (data['destinationLng'] as num?)?.toDouble(),
      fare: (data['fare'] as num?)?.toDouble(),
      vehicleType: data['vehicleType'] as String?,
      status: _statusFromString(data['status'] as String?),
      distance: data['distance'] as String?,
      etaText: data['etaText'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// إنشاء من JSON القادم من الباك إند (REST API).
  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: (json['id'] ?? json['_id'] ?? json['rideId']) as String? ?? '',
      riderId: json['riderId'] as String?,
      riderName: json['riderName'] as String?,
      pickupAddress: json['pickupAddress'] as String?,
      destinationAddress:
          json['destinationAddress'] as String? ??
          json['dropoffAddress'] as String?,
      pickupLat: (json['pickupLat'] as num?)?.toDouble(),
      pickupLng: (json['pickupLng'] as num?)?.toDouble(),
      destinationLat: (json['destinationLat'] as num?)?.toDouble(),
      destinationLng: (json['destinationLng'] as num?)?.toDouble(),
      fare: (json['fare'] as num?)?.toDouble(),
      vehicleType: json['vehicleType'] as String?,
      status: _statusFromString(json['status'] as String?),
      distance: json['distance'] as String?,
      etaText: json['etaText'] as String?,
      createdAt: _dateFromJson(json['createdAt']),
    );
  }

  /// تحليل تاريخ من عدة صيغ محتملة (ISO string أو timestamp بـ seconds/ms).
  static DateTime? _dateFromJson(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is num) {
      final ms = value.toInt();
      // أقل من 1e12 يُعتبر ثوانٍ، وإلا ملي ثوانٍ
      return DateTime.fromMillisecondsSinceEpoch(ms < 1e12 ? ms * 1000 : ms);
    }
    return null;
  }

  /// تحويل نص حالة Firestore إلى [RideStatus] (افتراضي pending)
  static RideStatus _statusFromString(String? value) {
    switch (value) {
      case 'accepted':
        return RideStatus.accepted;
      case 'arrived':
        return RideStatus.arrived;
      case 'started':
        return RideStatus.started;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      case 'pending':
      default:
        return RideStatus.pending;
    }
  }
}
