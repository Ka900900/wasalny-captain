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
  final String? riderPhone;
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
    this.riderPhone,
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
    String? riderPhone,
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
      riderPhone: riderPhone ?? this.riderPhone,
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
      riderPhone: data['riderPhone'] as String?,
      pickupAddress: data['pickupAddress'] as String?,
      destinationAddress: data['destinationAddress'] as String?,
      pickupLat: _toDouble(data['pickupLat'] ?? data['originLat']),
      pickupLng: _toDouble(data['pickupLng'] ?? data['originLng']),
      destinationLat: _toDouble(data['destinationLat'] ?? data['destLat']),
      destinationLng: _toDouble(data['destinationLng'] ?? data['destLng']),
      fare: _toDouble(data['fare'] ?? data['price']),
      vehicleType: data['vehicleType'] as String?,
      status: _statusFromString(data['status'] as String?),
      distance: _distanceToString(
        data['distance'] ?? data['distanceKm'] ?? data['distanceText'],
      ),
      etaText: data['etaText'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// إنشاء من JSON القادم من الباك إند (REST API).
  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      // ═══════════════════════════════════════════════════
      // ملاحظة: الباك إند عبر السوكيت قد ترسل الحقول بأسماء
      // مختلفة. نتعامل مع كل البدائل الممكنة هنا.
      // ═══════════════════════════════════════════════════
      id: (json['id'] ?? json['_id'] ?? json['rideId']) as String? ?? '',
      riderId:
          (json['riderId'] ?? json['userId'] ?? json['rider'] ?? json['user'])
              as String?,
      riderName:
          (json['riderName'] ??
                  json['userName'] ??
                  json['rider_name'] ??
                  json['user_name'] ??
                  json['name'])
              as String?,
      riderPhone:
          (json['riderPhone'] ??
                  json['userPhone'] ??
                  json['phone'] ??
                  json['phoneNumber'] ??
                  _nestedPhone(json['rider']) ??
                  _nestedPhone(json['user']) ??
                  _nestedPhone(json['passenger']))
              as String?,
      pickupAddress:
          (json['pickupAddress'] ??
                  json['pickup'] ??
                  json['origin'] ??
                  json['originAddress'] ??
                  json['from'])
              as String?,
      destinationAddress:
          (json['destinationAddress'] ??
                  json['destination'] ??
                  json['dest'] ??
                  json['dropoffAddress'] ??
                  json['dropoff'] ??
                  json['to'])
              as String?,
      pickupLat: _toDouble(
        json['pickupLat'] ??
            json['originLat'] ??
            json['pickup_lat'] ??
            json['origin_lat'] ??
            json['fromLat'],
      ),
      pickupLng: _toDouble(
        json['pickupLng'] ??
            json['originLng'] ??
            json['pickup_lng'] ??
            json['origin_lng'] ??
            json['fromLng'],
      ),
      destinationLat: _toDouble(
        json['destinationLat'] ??
            json['destLat'] ??
            json['destination_lat'] ??
            json['dest_lat'] ??
            json['toLat'],
      ),
      destinationLng: _toDouble(
        json['destinationLng'] ??
            json['destLng'] ??
            json['destination_lng'] ??
            json['dest_lng'] ??
            json['toLng'],
      ),
      fare: _toDouble(
        json['fare'] ??
            json['price'] ??
            json['amount'] ??
            json['estimatedFare'] ??
            json['estimated_price'],
      ),
      vehicleType:
          (json['vehicleType'] ??
                  json['rideType'] ??
                  json['vehicle_type'] ??
                  json['ride_type'])
              as String?,
      status: _statusFromString(json['status'] as String?),
      distance: _distanceToString(
        json['distance'] ??
            json['distanceKm'] ??
            json['distanceText'] ??
            json['distance_text'] ??
            json['distance_km'],
      ),
      etaText:
          (json['etaText'] ??
                  json['eta'] ??
                  json['duration'] ??
                  json['durationText'] ??
                  json['duration_text'])
              as String?,
      createdAt: _dateFromJson(
        json['createdAt'] ??
            json['_timestamp'] ??
            json['timestamp'] ??
            json['created_at'] ??
            json['time'],
      ),
    );
  }

  /// تحويل قيمة إلى double بأمان (تقبل num أو String رقمية مثل "50.00").
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  /// تحويل المسافة إلى نص آمن (تقبل num أو String).
  /// - لو num مثل 3.2 → "3.2 كم"
  /// - لو String "3.2" → "3.2 كم"
  /// - لو String "3.2 كم" → تُترك كما هي
  static String? _distanceToString(dynamic value) {
    if (value == null) return null;
    if (value is num) return '${value.toStringAsFixed(1)} كم';
    if (value is String) {
      final v = value.trim();
      if (v.isEmpty) return null;
      final hasUnit = v.contains('كم') || v.contains('km');
      return hasUnit ? v : '$v كم';
    }
    return value.toString();
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

  /// استخراج رقم هاتف الراكب من كائن متداخل مثل `{ rider: { phoneNumber } }`
  /// (كما يُرجع الباك إند من `GET /rides/current`).
  static String? _nestedPhone(dynamic obj) {
    if (obj is Map) {
      final v = obj['phoneNumber'] ?? obj['phone'] ?? obj['riderPhone'];
      return v?.toString();
    }
    return null;
  }
}
