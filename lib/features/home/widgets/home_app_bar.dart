import 'package:flutter/material.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';

/// Compact translucent top bar for the captain home screen.
///
/// Shows the online/offline status badge on the left and quick-action
/// icon buttons on the right (profile, notifications, safety).
class HomeAppBar extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSafetyTap;
  final bool isOnline;
  final bool hasActiveTrip;
  final ValueChanged<bool>? onToggleOnline;

  const HomeAppBar({
    super.key,
    this.onProfileTap,
    this.onNotificationsTap,
    this.onSafetyTap,
    this.isOnline = false,
    this.hasActiveTrip = false,
    this.onToggleOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'شريط الأدوات العلوي',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // ── Online/Offline Switch ───────────────────
            // The captain's availability toggle (sends Online/Offline to the
            // server via the parent's _toggleOnlineStatus handler).
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? AppColors.successContainer : AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: isOnline
                      ? const Color.fromARGB(255, 39, 207, 9).withValues(alpha: 0.5)
                      : const Color.fromARGB(255, 102, 102, 102),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: isOnline ? AppColors.success : AppColors.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'متصل' : 'غير متصل',
                    style: AppTextStyles.labelSmall?.copyWith(
                      color: isOnline
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: isOnline,
                    onChanged: hasActiveTrip ? null : onToggleOnline,
                    activeThumbColor: AppColors.success,
                    activeTrackColor: AppColors.success.withValues(alpha: 0.4),
                    inactiveThumbColor: AppColors.textMuted,
                    inactiveTrackColor: AppColors.border,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    // ignore: avoid_redundant_argument_values
                    splashRadius: 0,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Profile ──────────────────────────────────
            _IconButton(
              icon: Icons.person_rounded,
              label: 'الملف الشخصي',
              onTap: onProfileTap,
            ),
            const SizedBox(width: 6),

            // ── Notifications ────────────────────────────
            _IconButton(
              icon: Icons.notifications_outlined,
              label: 'الإشعارات',
              onTap: onNotificationsTap,
              showBadge: true,
            ),
            const SizedBox(width: 6),

            // ── Safety ───────────────────────────────────
            _IconButton(
              icon: Icons.shield_outlined,
              label: 'الأمان',
              onTap: onSafetyTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Consistent icon button for the top bar.
class _IconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showBadge;

  const _IconButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 22),
              if (showBadge)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
