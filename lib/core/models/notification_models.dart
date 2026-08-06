/// The category of a push notification sent to the captain.
enum NotificationType {
  /// A new ride request arrived.
  newRide,

  /// An existing trip status changed (e.g. accepted, started, cancelled).
  tripUpdate,

  /// Wallet balance changed or a withdrawal request was processed.
  walletUpdate,

  /// Promotional or informational message.
  promotion,

  /// An announcement broadcast by the admin (تحديث / عرض / مسابقة / إعلان).
  adminAnnouncement;

  /// Deserialise from the Firestore string value.
  static NotificationType fromString(String value) {
    switch (value) {
      case 'new_ride':
        return NotificationType.newRide;
      case 'trip_update':
        return NotificationType.tripUpdate;
      case 'wallet_update':
        return NotificationType.walletUpdate;
      case 'promotion':
        return NotificationType.promotion;
      case 'ADMIN_ANNOUNCEMENT':
      case 'admin_announcement':
      case 'campaign':
        return NotificationType.adminAnnouncement;
      default:
        return NotificationType.promotion;
    }
  }

  /// Serialise to the Firestore string value.
  String get asString {
    switch (this) {
      case NotificationType.newRide:
        return 'new_ride';
      case NotificationType.tripUpdate:
        return 'trip_update';
      case NotificationType.walletUpdate:
        return 'wallet_update';
      case NotificationType.promotion:
        return 'promotion';
      case NotificationType.adminAnnouncement:
        return 'admin_announcement';
    }
  }

  /// Localised display name.
  String get displayName {
    switch (this) {
      case NotificationType.newRide:
        return 'طلب رحلة جديد';
      case NotificationType.tripUpdate:
        return 'تحديث الرحلة';
      case NotificationType.walletUpdate:
        return 'تحديث المحفظة';
      case NotificationType.promotion:
        return 'عرض';
      case NotificationType.adminAnnouncement:
        return 'إعلان من الإدارة';
    }
  }

  /// Icon identifier used in the UI.
  String get iconName {
    switch (this) {
      case NotificationType.newRide:
        return 'ride';
      case NotificationType.tripUpdate:
        return 'trip';
      case NotificationType.walletUpdate:
        return 'wallet';
      case NotificationType.promotion:
        return 'promotion';
      case NotificationType.adminAnnouncement:
        return 'announcement';
    }
  }
}

/// A push notification stored in Firestore and displayed in the app.
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;

  /// Optional payload that can be used for navigation (e.g. rideId, walletTxId).
  final Map<String, dynamic>? data;

  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  /// Creates an [AppNotification] from a Firestore document snapshot.
  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      type: NotificationType.fromString(map['type'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      data: map['data'] is Map<String, dynamic>
          ? map['data'] as Map<String, dynamic>
          : null,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  /// Creates an [AppNotification] from a backend API notification object
  /// (e.g. `GET /api/v1/captain/notifications`). `createdAt` is an ISO string.
  factory AppNotification.fromBackendJson(Map<String, dynamic> map) {
    final rawCreated = map['createdAt'];
    DateTime created;
    if (rawCreated is DateTime) {
      created = rawCreated;
    } else {
      created =
          DateTime.tryParse(rawCreated?.toString() ?? '') ?? DateTime.now();
    }
    return AppNotification(
      id:
          map['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.fromString(map['type'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      data: map['data'] is Map<String, dynamic>
          ? map['data'] as Map<String, dynamic>
          : null,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: created,
    );
  }

  /// Converts this notification to a Map for Firestore.
  Map<String, dynamic> toMap() => {
    'type': type.asString,
    'title': title,
    'body': body,
    'data': data,
    'isRead': isRead,
    'createdAt': createdAt,
  };

  /// Returns a copy with the given fields replaced.
  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
