import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';

/// Compact pill-shaped online/offline toggle button.
///
/// Placed at the top of the home screen as a small status indicator.
///
/// **Visual states:**
/// - **Online:** Bright green/gradient, pulsing glow dot, "متصل"
/// - **Offline:** Neutral dark-grey, "غير متصل"
/// - **Loading:** Circular spinner inside the button while API processes
class OnlineToggleButton extends StatefulWidget {
  final bool isOnline;
  final bool hasActiveTrip;
  final bool isLoading;
  final ValueChanged<bool> onToggle;

  const OnlineToggleButton({
    super.key,
    required this.isOnline,
    required this.hasActiveTrip,
    this.isLoading = false,
    required this.onToggle,
  });

  @override
  State<OnlineToggleButton> createState() => _OnlineToggleButtonState();
}

class _OnlineToggleButtonState extends State<OnlineToggleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isOnline) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(OnlineToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !oldWidget.isOnline) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isOnline && oldWidget.isOnline) {
      _pulseController.stop();
      _pulseController.reset();
    }
    // Stop pulsing animation while loading
    if (widget.isLoading) {
      _pulseController.stop();
    } else if (widget.isOnline && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    debugPrint(
      'OnlineToggleButton clicked! current isOnline: ${widget.isOnline}',
    );
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {
      // Some devices/platforms may not support heavy impact haptics;
      // silently ignore to avoid blocking the toggle callback.
    }
    widget.onToggle(!widget.isOnline);
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled =
        widget.isLoading || (widget.isOnline && widget.hasActiveTrip);

    return Semantics(
      label: widget.isOnline ? 'إيقاف التشغيل' : 'تشغيل',
      hint: widget.hasActiveTrip
          ? 'لا يمكن إيقاف التشغيل أثناء رحلة نشطة'
          : null,
      child: GestureDetector(
        onTap: disabled ? null : _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          decoration: BoxDecoration(
            color: widget.isOnline ? const Color(0xFF10B981) : AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            border: Border.all(
              color: widget.isOnline
                  ? const Color(0xFF059669)
                  : AppColors.border,
              width: 1.2,
            ),
            boxShadow: widget.isOnline
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon: spinner when loading, dot otherwise ──
              if (widget.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.isOnline
                            ? Colors.white
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                        boxShadow: widget.isOnline
                            ? [
                                BoxShadow(
                                  color: Colors.white.withValues(
                                    alpha: _pulseAnimation.value * 0.5,
                                  ),
                                  blurRadius: 6,
                                  spreadRadius: _pulseAnimation.value * 2,
                                ),
                              ]
                            : [],
                      ),
                    );
                  },
                ),
              const SizedBox(width: 8),

              // ── Label (single line) ──
              Text(
                widget.isLoading
                    ? (widget.isOnline ? 'جارٍ الإيقاف…' : 'جارٍ التشغيل…')
                    : (widget.isOnline ? 'متصل' : 'غير متصل'),
                style: TextStyle(
                  color: widget.isOnline
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(width: 6),

              // ── Power icon ──
              Icon(
                widget.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 16,
                color: widget.isOnline ? Colors.white : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
