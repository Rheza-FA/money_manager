import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/app_haptics.dart';

const Duration _kPressDownDuration = Duration(milliseconds: 72);
const Duration _kReleaseUpDuration = Duration(milliseconds: 170);
const Duration _kCancelRestoreDuration = Duration(milliseconds: 140);

const Curve _kPressDownCurve = Cubic(0.20, 0.88, 0.28, 1.0);
const Curve _kReleaseSpringCurve = Cubic(0.16, 1.0, 0.30, 1.0);

double _resolvePressedScale(double? explicitScale, BuildContext context) {
  if (explicitScale != null) return explicitScale;

  final RenderObject? renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    final Size size = renderObject.size;
    final double maxSide = math.max(size.width, size.height);
    if (maxSide > 0.0) {
      final double t = ((maxSide - 44.0) / (360.0 - 44.0)).clamp(0.0, 1.0);
      final double eased = Curves.easeOutQuad.transform(t);
      return 0.915 + ((0.970 - 0.915) * eased);
    }
  }
  return 0.95;
}

/// Non-intrusive physical-switch wrapper for dedicated buttons
/// (e.g., [IconButton], [ElevatedButton], bottom navigation actions, steppers).
///
/// Uses a passive [Listener] so it never competes in Flutter's [GestureArena].
/// Synchronizes inward visual scale compression and return-spring rebound in
/// exact lockstep with two-phase tactile haptics ([AppHaptics.pressDown] on
/// inward actuation and [AppHaptics.releaseUp] when springing back up),
/// guaranteeing both pulses and full visual travel even on brisk quick clicks.
class TactilePress extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double? pressedScale;
  final HitTestBehavior behavior;

  const TactilePress({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale,
    this.behavior = HitTestBehavior.deferToChild,
  });

  @override
  State<TactilePress> createState() => _TactilePressState();
}

class _TactilePressState extends State<TactilePress>
    with SingleTickerProviderStateMixin {
  static const double _boundsSlop = 24.0;

  late final AnimationController _controller;

  int? _activePointer;
  Offset? _downPosition;
  bool _cancelled = false;
  bool _releaseScheduled = false;
  int _pressEpoch = 0;
  double _targetScale = 0.95;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant TactilePress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled && _activePointer != null) {
      _cancelPress();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _releaseScheduled) {
      _executeRelease();
    }
  }

  void _startPress() {
    _targetScale = _resolvePressedScale(widget.pressedScale, context);
    _releaseScheduled = false;
    _pressEpoch = AppHaptics.feedbackEpoch;
    AppHaptics.pressDown();

    if (_controller.value >= 1.0) {
      _controller.value = 0.999;
    }
    _controller.animateTo(
      1.0,
      duration: _kPressDownDuration,
      curve: _kPressDownCurve,
    );
  }

  void _scheduleOrExecuteRelease() {
    if (_controller.status == AnimationStatus.completed ||
        (!_controller.isAnimating && _controller.value >= 1.0)) {
      _executeRelease();
    } else {
      _releaseScheduled = true;
    }
  }

  void _executeRelease() {
    _releaseScheduled = false;
    if (AppHaptics.feedbackEpoch == _pressEpoch) {
      AppHaptics.releaseUp();
    }
    _controller.animateBack(
      0.0,
      duration: _kReleaseUpDuration,
      curve: _kReleaseSpringCurve,
    );
  }

  void _cancelPress() {
    _activePointer = null;
    _downPosition = null;
    _cancelled = true;
    _releaseScheduled = false;
    if (_controller.value > 0.0 || _controller.isAnimating) {
      _controller.animateBack(
        0.0,
        duration: _kCancelRestoreDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled || _activePointer != null) return;
    if (event.buttons != 0 && (event.buttons & kPrimaryButton) == 0) return;

    _activePointer = event.pointer;
    _downPosition = event.localPosition;
    _cancelled = false;
    _startPress();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _cancelled) return;

    final Offset? origin = _downPosition;
    if (origin != null &&
        (event.localPosition - origin).distance > kTouchSlop) {
      _cancelPress();
      return;
    }

    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final Rect sloppyBounds = Rect.fromLTWH(
        -_boundsSlop,
        -_boundsSlop,
        renderObject.size.width + (_boundsSlop * 2),
        renderObject.size.height + (_boundsSlop * 2),
      );
      if (!sloppyBounds.contains(event.localPosition)) {
        _cancelPress();
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;

    final bool wasCancelled = _cancelled;
    _activePointer = null;
    _downPosition = null;
    _cancelled = false;

    if (wasCancelled) return;
    _scheduleOrExecuteRelease();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointer) {
      _cancelPress();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double scale = 1.0 - ((1.0 - _targetScale) * _controller.value);
          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            transformHitTests: false,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Scroll-safe physical-switch tap wrapper for pressable components that live
/// inside scrollable containers ([CustomScrollView], [SingleChildScrollView],
/// [PageView]).
///
/// - **Scrolling / swiping:** [Scrollable] or [Dismissible] wins the gesture
///   arena, so zero haptics and zero scale compression occur during drags.
/// - **Quick click (`< 100ms`):** Immediately fires [AppHaptics.pressDown] and
///   compresses to the physical stop over `72ms`, then fires
///   [AppHaptics.releaseUp] in exact lockstep as the button springs back to `1.0`.
/// - **Held press (`>= 100ms`):** Fires [AppHaptics.pressDown] and holds the
///   compressed button beneath the finger until lifted, then fires
///   [AppHaptics.releaseUp] as it springs back.
class TactileTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? pressedScale;
  final HitTestBehavior behavior;

  const TactileTap({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<TactileTap> createState() => _TactileTapState();
}

class _TactileTapState extends State<TactileTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _pressStarted = false;
  bool _releaseScheduled = false;
  int _pressEpoch = 0;
  double _targetScale = 0.95;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant TactileTap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null && oldWidget.onTap != null && _pressStarted) {
      _handleTapCancel();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _releaseScheduled) {
      _executeRelease();
    }
  }

  void _startPress() {
    _targetScale = _resolvePressedScale(widget.pressedScale, context);
    _pressStarted = true;
    _releaseScheduled = false;
    _pressEpoch = AppHaptics.feedbackEpoch;
    AppHaptics.pressDown();

    if (_controller.value >= 1.0) {
      _controller.value = 0.999;
    }
    _controller.animateTo(
      1.0,
      duration: _kPressDownDuration,
      curve: _kPressDownCurve,
    );
  }

  void _scheduleOrExecuteRelease() {
    if (_controller.status == AnimationStatus.completed ||
        (!_controller.isAnimating && _controller.value >= 1.0)) {
      _executeRelease();
    } else {
      _releaseScheduled = true;
    }
  }

  void _executeRelease() {
    _releaseScheduled = false;
    if (AppHaptics.feedbackEpoch == _pressEpoch) {
      AppHaptics.releaseUp();
    }
    _controller.animateBack(
      0.0,
      duration: _kReleaseUpDuration,
      curve: _kReleaseSpringCurve,
    );
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    if (!_pressStarted) {
      _startPress();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    if (!_pressStarted) {
      _startPress();
    }
    _pressStarted = false;
    _scheduleOrExecuteRelease();
  }

  void _handleTapCancel() {
    _pressStarted = false;
    _releaseScheduled = false;
    if (_controller.value > 0.0 || _controller.isAnimating) {
      _controller.animateBack(
        0.0,
        duration: _kCancelRestoreDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.onTap != null ? _handleTapDown : null,
      onTapUp: widget.onTap != null ? _handleTapUp : null,
      onTapCancel: widget.onTap != null ? _handleTapCancel : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double scale = 1.0 - ((1.0 - _targetScale) * _controller.value);
          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            transformHitTests: false,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
