import 'package:flutter/material.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// ───────────────────────────────────────────────────────────────
/// Waslny Status Indicators — Reusable status display widgets.
/// ───────────────────────────────────────────────────────────────
///
/// - [WaslnyStatusBadge] — Small badge/chip (e.g. "نشط", "معلق")
/// - [WaslnyStatusDot] — Pulsing animated status dot
/// - [WaslnyConnectionBanner] — Full-width online/offline banner

// ═══════════════════════════════════════════════════════════════
// STATUS BADGE
// ═══════════════════════════════════════════════════════════════

/// A small colored badge showing a status label.
///
/// Variants:
/// - `success` — Green (e.g. active, completed, online)
/// - `warning` — Amber (e.g. pending, suspended)
/// - `error`   — Red (e.g. rejected, offline, failed)
/// - `info`    — Blue (e.g. in-progress, processing)
/// - `neutral` — Grey (e.g. inactive, draft)
/// - `custom`  — User-defined color
class WaslnyStatusBadge extends StatelessWidget {
  final String label;
  final WaslnyStatusType type;
  final Color? customColor;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final IconData? icon;

  const WaslnyStatusBadge({
    super.key,
    required this.label,
    this.type = WaslnyStatusType.neutral,
    this.customColor,
    this.fontSize = 12,
    this.padding,
    this.icon,
  });

  /// Green success badge.
  const WaslnyStatusBadge.success(
    this.label, {
    super.key,
    this.fontSize = 12,
    this.padding,
    this.icon,
  }) : type = WaslnyStatusType.success,
       customColor = null;

  /// Amber warning badge.
  const WaslnyStatusBadge.warning(
    this.label, {
    super.key,
    this.fontSize = 12,
    this.padding,
    this.icon,
  }) : type = WaslnyStatusType.warning,
       customColor = null;

  /// Red error badge.
  const WaslnyStatusBadge.error(
    this.label, {
    super.key,
    this.fontSize = 12,
    this.padding,
    this.icon,
  }) : type = WaslnyStatusType.error,
       customColor = null;

  /// Blue info badge.
  const WaslnyStatusBadge.info(
    this.label, {
    super.key,
    this.fontSize = 12,
    this.padding,
    this.icon,
  }) : type = WaslnyStatusType.info,
       customColor = null;

  /// Grey neutral badge.
  const WaslnyStatusBadge.neutral(
    this.label, {
    super.key,
    this.fontSize = 12,
    this.padding,
    this.icon,
  }) : type = WaslnyStatusType.neutral,
       customColor = null;

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return Container(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: colors.foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  _StatusColors _getColors() {
    if (customColor != null) {
      return _StatusColors(
        foreground: customColor!,
        background: customColor!.withValues(alpha: 0.15),
        border: customColor!.withValues(alpha: 0.3),
      );
    }
    switch (type) {
      case WaslnyStatusType.success:
        return _StatusColors(
          foreground: AppColors.success,
          background: AppColors.successContainer,
          border: AppColors.success.withValues(alpha: 0.3),
        );
      case WaslnyStatusType.warning:
        return _StatusColors(
          foreground: AppColors.warning,
          background: AppColors.warningContainer,
          border: AppColors.warning.withValues(alpha: 0.3),
        );
      case WaslnyStatusType.error:
        return _StatusColors(
          foreground: AppColors.error,
          background: AppColors.errorContainer,
          border: AppColors.error.withValues(alpha: 0.3),
        );
      case WaslnyStatusType.info:
        return _StatusColors(
          foreground: AppColors.info,
          background: AppColors.infoContainer,
          border: AppColors.info.withValues(alpha: 0.3),
        );
      case WaslnyStatusType.neutral:
        return _StatusColors(
          foreground: AppColors.textMuted,
          background: AppColors.card,
          border: AppColors.border,
        );
    }
  }
}

enum WaslnyStatusType { success, warning, error, info, neutral }

class _StatusColors {
  final Color foreground;
  final Color background;
  final Color border;
  const _StatusColors({
    required this.foreground,
    required this.background,
    required this.border,
  });
}

// ═══════════════════════════════════════════════════════════════
// STATUS DOT
// ═══════════════════════════════════════════════════════════════

/// An animated pulsing status dot.
///
/// - `success` — Green pulsing dot (online, active)
/// - `error`   — Red static dot (offline, error)
/// - `warning` — Amber static dot (away, pending)
/// - `neutral` — Grey static dot (inactive)
class WaslnyStatusDot extends StatefulWidget {
  final WaslnyStatusType type;
  final double size;
  final Color? color;

  const WaslnyStatusDot({
    super.key,
    this.type = WaslnyStatusType.success,
    this.size = 10,
    this.color,
  });

  @override
  State<WaslnyStatusDot> createState() => _WaslnyStatusDotState();
}

class _WaslnyStatusDotState extends State<WaslnyStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.type == WaslnyStatusType.success) {
      _controller.repeat(reverse: true);
    }

    _pulse = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _color {
    if (widget.color != null) return widget.color!;
    switch (widget.type) {
      case WaslnyStatusType.success:
        return AppColors.success;
      case WaslnyStatusType.warning:
        return AppColors.warning;
      case WaslnyStatusType.error:
        return AppColors.error;
      case WaslnyStatusType.info:
        return AppColors.info;
      case WaslnyStatusType.neutral:
        return AppColors.textMuted;
    }
  }

  bool get _shouldAnimate => widget.type == WaslnyStatusType.success;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: _shouldAnimate
                ? [
                    BoxShadow(
                      color: _color.withValues(alpha: 0.5 * _pulse.value),
                      blurRadius: widget.size * 0.6,
                      spreadRadius: widget.size * 0.2,
                    ),
                  ]
                : null,
          ),
          child: Transform.scale(
            scale: _shouldAnimate ? _pulse.value : 1.0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              margin: EdgeInsets.all(widget.size * 0.2),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CONNECTION BANNER
// ═══════════════════════════════════════════════════════════════

/// A full-width banner indicating online/offline connection status.
///
/// - [isOnline] — Green banner indicating the driver is online
/// - [!isOnline] — Red banner indicating the driver is offline
/// - [isLoading] — Shows a subtle loading state
class WaslnyConnectionBanner extends StatelessWidget {
  final bool isOnline;
  final bool isLoading;
  final String? onlineText;
  final String? offlineText;
  final VoidCallback? onToggle;

  const WaslnyConnectionBanner({
    super.key,
    required this.isOnline,
    this.isLoading = false,
    this.onlineText,
    this.offlineText,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isOnline ? AppColors.success : AppColors.error;
    final icon = isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded;
    final text = isOnline
        ? (onlineText ?? 'متصل — تستقبل الطلبات الآن')
        : (offlineText ?? 'غير متصل — لا تستقبل طلبات');

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.15),
          border: Border(
            bottom: BorderSide(color: bgColor.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: bgColor,
                ),
              )
            else
              Icon(icon, color: bgColor, size: AppSpacing.iconLg),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.labelMedium?.copyWith(color: bgColor),
              ),
            ),
            if (onToggle != null)
              Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.textMuted,
                size: AppSpacing.iconMd,
              ),
          ],
        ),
      ),
    );
  }
}
