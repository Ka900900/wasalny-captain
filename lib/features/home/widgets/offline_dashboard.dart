import 'package:flutter/material.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/core/models/earnings_data.dart';
import 'package:waslny_captain/core/models/wallet_models.dart';

/// Dashboard panel shown when the captain is offline.
///
/// Displays earnings summary, wallet balance, trip statistics, and
/// an offline-status hint card.
class OfflineDashboard extends StatelessWidget {
  final EarningsData? earningsData;
  final WalletData? walletData;
  final bool isLoading;
  final VoidCallback? onEarningsTap;
  final VoidCallback? onWalletTap;

  const OfflineDashboard({
    super.key,
    this.earningsData,
    this.walletData,
    this.isLoading = false,
    this.onEarningsTap,
    this.onWalletTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // ── Welcome header ──
        Semantics(
          label: 'مرحباً بك',
          child: Column(
            children: [
              Text(
                'مرحباً بك في وصلني كابتن',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'اضغط على متصل لبدء استقبال الرحلات',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // ── Earnings Card ──
        _DashboardCard(
          icon: Icons.trending_up_rounded,
          iconColor: AppColors.primary,
          title: 'أرباح اليوم',
          value: earningsData != null
              ? '${earningsData!.totalAmount.toStringAsFixed(0)} ج.م'
              : '---',
          subtitle: '${earningsData?.totalTrips ?? 0} رحلة',
          onTap: onEarningsTap,
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Wallet Card ──
        _DashboardCard(
          icon: Icons.wallet_rounded,
          iconColor: AppColors.warning,
          title: 'رصيد المحفظة',
          value: walletData != null
              ? '${walletData!.balance.toStringAsFixed(0)} ج.م'
              : '---',
          subtitle:
              'المسحوبات: ${walletData?.totalWithdrawn.toStringAsFixed(0) ?? '---'} ج.م',
          onTap: onWalletTap,
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Trip Stats Card ──
        _DashboardCard(
          icon: Icons.directions_car_rounded,
          iconColor: AppColors.primary,
          title: 'إحصائيات الرحلات',
          value: '${earningsData?.totalTrips ?? 0}',
          subtitle:
              'المسافة: ${earningsData?.totalDistanceKm.toStringAsFixed(1) ?? '---'} كم',
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Offline Status Hint ──
        _OfflineHintCard(),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// A single stat card used in the dashboard.
class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title: $value',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: AppTextStyles.headlineMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_left,
                  color: AppColors.textMuted,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offline-status hint card.
class _OfflineHintCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.power_settings_new_rounded,
              color: AppColors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'غير متصل',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'اضغط على زر متصل للبدء',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
