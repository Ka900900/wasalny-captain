/// Status of an SOS alert.
enum SOSStatus {
  /// The SOS has been triggered and is currently active.
  active,

  /// The SOS has been manually resolved by the captain.
  resolved,

  /// The SOS was cancelled (e.g. accidental trigger).
  cancelled;

  /// Deserialise from the Firestore string value.
  static SOSStatus fromString(String value) {
    switch (value) {
      case 'active':
        return SOSStatus.active;
      case 'resolved':
        return SOSStatus.resolved;
      case 'cancelled':
        return SOSStatus.cancelled;
      default:
        return SOSStatus.active;
    }
  }

  /// Serialise to the Firestore string value.
  String get asString => name;

  /// Localised display name.
  String get displayName {
    switch (this) {
      case SOSStatus.active:
        return 'نشط';
      case SOSStatus.resolved:
        return 'تم الحل';
      case SOSStatus.cancelled:
        return 'ملغي';
    }
  }
}

/// An emergency contact saved by the captain.
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final DateTime createdAt;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.createdAt,
  });

  /// Creates an [EmergencyContact] from a Firestore document snapshot.
  factory EmergencyContact.fromMap(String id, Map<String, dynamic> map) {
    return EmergencyContact(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this contact to a Map for Firestore.
  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'createdAt': createdAt,
      };

  /// Returns a copy with the given fields replaced.
  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relationship,
  }) {
    return EmergencyContact(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      createdAt: createdAt,
    );
  }
}

/// An SOS alert triggered by the captain.
class SOSAlert {
  final String id;
  final SOSStatus status;

  /// Location where the SOS was triggered.
  final double? latitude;
  final double? longitude;

  final DateTime createdAt;

  /// When the alert was resolved / cancelled.
  final DateTime? resolvedAt;

  /// IDs of the emergency contacts that were notified.
  final List<String> notifiedContactIds;

  const SOSAlert({
    required this.id,
    required this.status,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.resolvedAt,
    this.notifiedContactIds = const [],
  });

  /// Creates an [SOSAlert] from a Firestore document snapshot.
  factory SOSAlert.fromMap(String id, Map<String, dynamic> map) {
    return SOSAlert(
      id: id,
      status: SOSStatus.fromString(map['status'] as String? ?? 'active'),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as dynamic)?.toDate(),
      notifiedContactIds: (map['notifiedContactIds'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
    );
  }

  /// Converts this alert to a Map for Firestore.
  Map<String, dynamic> toMap() => {
        'status': status.asString,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt,
        'resolvedAt': resolvedAt,
        'notifiedContactIds': notifiedContactIds,
      };
}

/// Current state of live location sharing.
class LiveSharingState {
  /// Whether the captain is currently sharing their location.
  final bool isSharing;

  /// The ID of the trip / person this is shared with, if any.
  final String? sharedWithId;

  /// When sharing started.
  final DateTime? startedAt;

  /// The latest known latitude.
  final double? latitude;

  /// The latest known longitude.
  final double? longitude;

  const LiveSharingState({
    this.isSharing = false,
    this.sharedWithId,
    this.startedAt,
    this.latitude,
    this.longitude,
  });

  /// Creates from a Firestore document snapshot.
  factory LiveSharingState.fromMap(Map<String, dynamic> map) {
    return LiveSharingState(
      isSharing: map['isSharing'] as bool? ?? false,
      sharedWithId: map['sharedWithId'] as String?,
      startedAt: (map['startedAt'] as dynamic)?.toDate(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  /// Converts to a Map for Firestore.
  Map<String, dynamic> toMap() => {
        'isSharing': isSharing,
        'sharedWithId': sharedWithId,
        'startedAt': startedAt,
        'latitude': latitude,
        'longitude': longitude,
      };
}
