import 'package:flutter/material.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// ───────────────────────────────────────────────────────────────
/// Waslny Card — Consistent card container with multiple variants.
/// ───────────────────────────────────────────────────────────────
///
/// Variants:
/// - [WaslnyCard] — Base card container with optional border, shadow, onTap
/// - [WaslnyStatCard] — Compact dashboard stat card (icon + label + value)
/// - [WaslnyActionCard] — Tappable card with a trailing arrow
/// - [WaslnyInfoCard] — Info/alert card with leading icon
///
/// All cards share the same visual language (dark surface, rounded corners).

// ═══════════════════════════════════════════════════════════════
// BASE CARD
// ═══════════════════════════════════════════════════════════════

/// A reusable card container with consistent Waslny styling.
///
/// Background: [AppColors.card] | Border: optional [AppColors.border]
/// Border radius: [AppSpacing.radiusXl] | Padding: [AppSpacing.xl]
class WaslnyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const WaslnyCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.card,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppSpacing.radiusXl,
        ),
        border: borderColor != null
            ? Border.all(color: borderColor!)
            : (onTap != null
                ? Border.all(color: AppColors.border)
                : null),
        boxShadow: boxShadow ?? AppColors.shadowSm,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

// ═══════════════════════════════════════════════════════════════
// STAT CARD
// ═══════════════════════════════════════════════════════════════

/// A compact stat card used in dashboards.
///
/// Displays an icon, label, and value with consistent styling.
class WaslnyStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const WaslnyStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = valueColor ?? iconColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: AppColors.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: AppSpacing.iconMd),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: AppTextStyles.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTextStyles.amountMedium?.copyWith(color: cardColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ACTION CARD
// ═══════════════════════════════════════════════════════════════

/// A tappable card with a trailing arrow icon.
///
/// Useful for menu items, settings rows, navigation tiles.
class WaslnyActionCard extends StatelessWidget {
  final IconData leadingIcon;
  final Color? leadingIconColor;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const WaslnyActionCard({
    super.key,
    this.leadingIcon = Icons.chevron_right,
    this.leadingIconColor,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: AppColors.shadowSm,
        ),
        child: Row(
          children: [
            // Leading
            if (leading != null)
              leading!
            else ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (leadingIconColor ?? AppColors.primary)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  leadingIcon,
                  color: leadingIconColor ?? AppColors.primary,
                  size: AppSpacing.iconMd,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.md),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Trailing
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: AppSpacing.iconLg,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// INFO CARD
// ═══════════════════════════════════════════════════════════════

/// An info/alert card with a leading icon and colored accent border.
///
/// Variants map to semantic colors (info, success, warning, error).
class WaslnyInfoCard extends StatelessWidget {
  final String message;
  final String? title;
  final WaslnyInfoCardType type;
  final IconData? icon;
  final VoidCallback? onDismiss;

  const WaslnyInfoCard({
    super.key,
    required this.message,
    this.title,
    this.type = WaslnyInfoCardType.info,
    this.icon,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final data = _infoData(type);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: data.backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border(
          left: BorderSide(color: data.accentColor, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? data.defaultIcon,
            color: data.accentColor,
            size: AppSpacing.iconLg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                    child: Text(
                      title!,
                      style: AppTextStyles.labelLarge?.copyWith(
                        color: data.accentColor,
                      ),
                    ),
                  ),
                Text(
                  message,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close,
                color: AppColors.textMuted,
                size: AppSpacing.iconMd,
              ),
            ),
        ],
      ),
    );
  }

  _InfoCardData _infoData(WaslnyInfoCardType type) {
    switch (type) {
      case WaslnyInfoCardType.info:
        return _InfoCardData(
          accentColor: AppColors.info,
          backgroundColor: AppColors.infoContainer,
          defaultIcon: Icons.info_outline,
        );
      case WaslnyInfoCardType.success:
        return _InfoCardData(
          accentColor: AppColors.success,
          backgroundColor: AppColors.successContainer,
          defaultIcon: Icons.check_circle_outline,
        );
      case WaslnyInfoCardType.warning:
        return _InfoCardData(
          accentColor: AppColors.warning,
          backgroundColor: AppColors.warningContainer,
          defaultIcon: Icons.warning_amber_outlined,
        );
      case WaslnyInfoCardType.error:
        return _InfoCardData(
          accentColor: AppColors.error,
          backgroundColor: AppColors.errorContainer,
          defaultIcon: Icons.error_outline,
        );
    }
  }
}

enum WaslnyInfoCardType { info, success, warning, error }

class _InfoCardData {
  final Color accentColor;
  final Color backgroundColor;
  final IconData defaultIcon;
  const _InfoCardData({
    required this.accentColor,
    required this.backgroundColor,
    required this.defaultIcon,
  });
}
