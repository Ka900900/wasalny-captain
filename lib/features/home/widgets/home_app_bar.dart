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

  const HomeAppBar({
    super.key,
    this.onProfileTap,
    this.onNotificationsTap,
    this.onSafetyTap,
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
