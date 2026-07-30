import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:waslny_captain/core/models/ride_model.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;

  /// يُستدعى عند استقبال رحلة جديدة متاحة من الباك إند عبر السوكيت
  /// (بديل آمن عن مستمع Firestore العام للرحلات المعلّقة).
  void Function(RideModel ride)? onNewAvailableRide;

  // تهيئة الاتصال بالسيرفر
  void initSocket(String userId, String token) {
    if (socket != null && socket!.connected) return;

    // تأكد من استخدام IP الكمبيوتر الصحيح بدلاً من localhost
    const String socketUrl =
        "https://wasalny-backend-production.up.railway.app";

    log('جاري الاتصال بسيرفر السوكيت: $socketUrl');

    socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports([
            'websocket',
          ]) // استخدام websocket فقط لسرعة واستقرار الاتصال
          .disableAutoConnect()
          .setQuery({
            'userId': userId,
            'role': 'DRIVER',
          }) // تمرير هوية الكابتن للسيرفر
          .setAuth({'token': token}) // تمرير توكن JWT ليتعرف عليه السيرفر
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      log('🟢 تم الاتصال بسيرفر السوكيت بنجاح!');
      // إرسال حدث الانضمام للسيرفر
      socket!.emit('join_driver', {'userId': userId});
    });

    socket!.onDisconnect((_) => log('🔴 تم قطع الاتصال بالسوكيت'));
    socket!.onConnectError((data) => log('⚠️ خطأ في الاتصال بالسوكيت: $data'));
    socket!.onError((data) => log('❌ خطأ في السوكيت: $data'));

    // استقبال طلبات الرحلات الجديدة (بديل عن مستمع Firestore العام).
    // الباك إند يبثّ الحدث لمرة واحدة للكابتن المخصّص له فقط.
    // ⚠️  بعض إصدارات الباك إند تُغلّف البيانات داخل مفتاح "ride":
    //     {"ride": {rideId, pickupAddress, ...}}
    //     وأخرى ترسلها مباشرة:
    //     {rideId, pickupAddress, ...}
    //     نتعامل مع الحالتين.
    socket!.on('ride.new_available', (data) {
      if (data is Map) {
        try {
          final map = Map<String, dynamic>.from(data);
          // إذا كانت البيانات مغلّفة داخل مفتاح ride، نفكّها
          final inner = (map['ride'] ?? map['data'] ?? map['trip']) as Map?;
          final ride = RideModel.fromJson(
            inner != null ? Map<String, dynamic>.from(inner) : map,
          );
          onNewAvailableRide?.call(ride);
        } catch (e) {
          log('⚠️ خطأ في تحليل بيانات الرحلة من السوكيت: $e');
        }
      }
    });
  }

  // إرسال الموقع الحالي لايف للسيرفر
  void emitLocation({
    required double lat,
    required double lng,
    String? rideId,
  }) {
    if (socket == null || !socket!.connected) {
      log('⚠️ السوكيت غير متصل. لا يمكن إرسال الموقع.');
      return;
    }

    socket!.emit('update-location', {'lat': lat, 'lng': lng, 'rideId': rideId});
    log('📤 تم إرسال الموقع عبر السوكيت: $lat, $lng');
  }

  // قطع الاتصال عند الخروج أو تحول الكابتن لـ Offline
  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
      socket = null;
      log('🔌 تم إغلاق السوكيت يدوياً.');
    }
  }
}
