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

  /// Play the dedicated ride‑alert sound (used for incoming "New Ride"
  /// notifications). It loops for a few seconds so it reliably grabs the
  /// captain's attention, then stops automatically.
  ///
  /// Works from the foreground. For background playback, the OS media player
  /// service keeps the [AudioPlayer] alive while the isolate is resident.
  Future<void> playRideAlert({Duration duration = const Duration(seconds: 5)}) async {
    if (_tripAlertPlayer.state == PlayerState.playing) return;
    await _tripAlertPlayer.stop();
    await _tripAlertPlayer.setSource(AssetSource('sounds/ride_alert.mp3'));
    await _tripAlertPlayer.setReleaseMode(ReleaseMode.loop);
    await _tripAlertPlayer.resume();
    // Stop the loop automatically after [duration] so it doesn't run forever.
    Future.delayed(duration, () async {
      if (_tripAlertPlayer.state == PlayerState.playing) {
        await _tripAlertPlayer.stop();
      }
    });
  }

  /// Play the ride‑alert sound in an **infinite loop** until explicitly
  /// stopped via [stopAlert].
  ///
  /// Used for incoming "New Ride" notifications so the captain is repeatedly
  /// alerted until they interact with the request (accept/reject). The loop
  /// keeps running across the foreground/background boundary as long as the
  /// audio player isolate is alive.
  Future<void> playLoopingAlert() async {
    if (_tripAlertPlayer.state == PlayerState.playing) return;
    await _tripAlertPlayer.stop();
    await _tripAlertPlayer.setSource(AssetSource('sounds/ride_alert.mp3'));
    await _tripAlertPlayer.setReleaseMode(ReleaseMode.loop);
    await _tripAlertPlayer.resume();
  }

  /// Stop the looping ride‑alert sound completely (used when the captain
  /// accepts or rejects the incoming ride request).
  Future<void> stopAlert() async {
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
