import 'package:flutter/services.dart';

/// Shared native channel for low-latency hardware transient haptics.
///
/// Backed by `TactileHapticChannel` on Android (`VibrationEffect.Composition`
/// LRA braking primitives with `USAGE_TOUCH` and calibrated two-stage waveform
/// fallbacks) and `IosTactileHapticEngine` on iOS (`CoreHaptics` high-sharpness
/// `.hapticTransient` events + pre-warmed `UIImpactFeedbackGenerator` fallbacks).
const MethodChannel kTactileHapticChannel = MethodChannel('neymo/haptics');

/// Physical-switch haptic feedback service modeled after iPhone's Taptic Engine.
///
/// Every method is fire-and-forget safe, creates zero Dart timers, and falls
/// back gracefully to standard [HapticFeedback] when running in environments
/// where the native channel is unavailable.
abstract final class AppHaptics {
  static int _feedbackEpoch = 0;

  /// Monotonically increasing epoch incremented whenever an explicit outcome
  /// haptic ([destructive], [success], [error]) fires, allowing active button
  /// release springs to avoid clobbering outcome waveforms.
  static int get feedbackEpoch => _feedbackEpoch;

  /// Crisp downward mechanical actuation transient (`0ms` press contact).
  static Future<void> pressDown() => _invoke(
        'pressDown',
        fallback: HapticFeedback.lightImpact,
      );

  /// Lighter return-spring transient synchronized with button rebound.
  static Future<void> releaseUp() => _invoke(
        'releaseUp',
        fallback: HapticFeedback.selectionClick,
      );

  /// Hardware-composed two-stage mechanical click (`press` + `62ms` + `release`).
  static Future<void> tapClick() => _invoke(
        'tapClick',
        fallback: HapticFeedback.lightImpact,
      );

  /// Firmer hardware-composed two-stage click (`press` + `64ms` + `release`).
  static Future<void> primaryClick() => _invoke(
        'primaryClick',
        fallback: HapticFeedback.mediumImpact,
      );

  /// Crisp single micro-detent for page snaps, focus transitions, and thresholds.
  static Future<void> softDetent() => _invoke(
        'softDetent',
        fallback: HapticFeedback.selectionClick,
      );

  /// Firm rigid transient for destructive thresholds and swipe-to-delete.
  static Future<void> destructive() {
    _feedbackEpoch++;
    return _invoke(
      'destructive',
      fallback: HapticFeedback.heavyImpact,
    );
  }

  /// Ascending double transient confirming a completed transaction save.
  static Future<void> success() {
    _feedbackEpoch++;
    return _invoke(
      'success',
      fallback: HapticFeedback.mediumImpact,
    );
  }

  /// Sharp staccato transient signaling validation errors without buzzy vibration.
  static Future<void> error() {
    _feedbackEpoch++;
    return _invoke(
      'error',
      fallback: HapticFeedback.heavyImpact,
    );
  }

  static Future<void> _invoke(
    String method, {
    required Future<void> Function() fallback,
  }) async {
    try {
      await kTactileHapticChannel.invokeMethod<void>(method);
    } on MissingPluginException {
      try {
        await fallback();
      } catch (_) {
        // Safely ignore in headless or unsupported environments.
      }
    } catch (_) {
      // Safely ignore platform or binding exceptions.
    }
  }
}
