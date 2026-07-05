import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// Legacy menu item widget — now uses AppColors for consistency.
/// Prefer using _ProfileMenuItem inside profile_screen.dart
/// or WaslnyActionCard from the design system for new screens.
class MenuItemWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const MenuItemWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 24),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: Text(title, style: AppTextStyles.titleSmall)),
            const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
