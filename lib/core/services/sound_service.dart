import 'package:audioplayers/audioplayers.dart';

/// Centralized service for playing all sounds in the app.
///
/// Two main sounds are provided:
/// - [playTripAlert] – looped alert for incoming ride requests
/// - [playNotificationAlert] – single-shot sound for push notifications
///
/// Usage:
/// ```dart
/// await SoundService.instance.playTripAlert();
/// await SoundService.instance.playNotificationAlert();
/// ```
class SoundService {
  // ── Singleton ───────────────────────────────────────
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _tripAlertPlayer = AudioPlayer();
  final AudioPlayer _notificationPlayer = AudioPlayer();

  // ────────────────────────────────────────────────────
  // Trip alert (looped)
  // ────────────────────────────────────────────────────

  /// Start playing the trip alert sound in a loop.
  Future<void> playTripAlert() async {
    if (_tripAlertPlayer.state == PlayerState.playing) return;
    await _tripAlertPlayer.stop();
    await _tripAlertPlayer.setSource(AssetSource('sounds/trip_alert.mp3'));
    await _tripAlertPlayer.setReleaseMode(ReleaseMode.loop);
    await _tripAlertPlayer.resume();
  }

  /// Stop the trip alert sound.
  Future<void> stopTripAlert() async {
    await _tripAlertPlayer.stop();
  }

  // ────────────────────────────────────────────────────
  // Notification alert (single‑shot)
  // ────────────────────────────────────────────────────

  /// Play the notification alert sound once.
  Future<void> playNotificationAlert() async {
    await _notificationPlayer.stop();
    await _notificationPlayer.setSource(
      AssetSource('sounds/notification_alert.mp3'),
    );
    await _notificationPlayer.setReleaseMode(ReleaseMode.release);
    await _notificationPlayer.resume();
  }

  // ────────────────────────────────────────────────────
  // Cleanup
  // ────────────────────────────────────────────────────

  /// Dispose both players. Call on app shutdown.
  void dispose() {
    _tripAlertPlayer.dispose();
    _notificationPlayer.dispose();
  }
}
