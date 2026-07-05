import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';

/// Large pill-shaped online/offline toggle button.
///
/// Placed at the bottom of the home screen as the primary action.
/// - **Offline:** Dark, subtle, shows "اضغط للتشغيل"
/// - **Online:** Green, glowing, shows "متصل — اضغط للإيقاف"
class OnlineToggleButton extends StatefulWidget {
  final bool isOnline;
  final bool hasActiveTrip;
  final ValueChanged<bool> onToggle;

  const OnlineToggleButton({
    super.key,
    required this.isOnline,
    required this.hasActiveTrip,
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.heavyImpact();
    widget.onToggle(!widget.isOnline);
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.isOnline && widget.hasActiveTrip;

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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: widget.isOnline ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: widget.isOnline ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
            boxShadow: widget.isOnline
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing / static dot
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.isOnline
                          ? AppColors.bg
                          : AppColors.textMuted,
                      shape: BoxShape.circle,
                      boxShadow: widget.isOnline
                          ? [
                              BoxShadow(
                                color: AppColors.bg.withValues(
                                  alpha: _pulseAnimation.value * 0.5,
                                ),
                                blurRadius: 8,
                                spreadRadius: _pulseAnimation.value * 3,
                              ),
                            ]
                          : [],
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),

              // Label
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isOnline ? 'متصل' : 'غير متصل',
                    style: TextStyle(
                      color: widget.isOnline
                          ? AppColors.bg
                          : AppColors.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!widget.isOnline)
                    Text(
                      'اضغط للتشغيل',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Power icon
              Icon(
                widget.isOnline
                    ? Icons.power_settings_new_rounded
                    : Icons.power_settings_new_rounded,
                size: 22,
                color: widget.isOnline ? AppColors.bg : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
