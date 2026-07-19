import 'package:flutter/material.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';

/// A card that displays a transparent fare breakdown returned by the
/// price-estimation endpoint.
///
/// Shows each component (base fare, distance cost, time cost) plus the
/// commission and the final total — with the [totalPrice] rendered
/// prominently in the brand accent colour.
///
/// All values are plain `double`s (matching the API JSON). The widget
/// formats them with 2 decimals and appends "ج.م".
class FareBreakdownCard extends StatelessWidget {
  final double baseFare;
  final double distanceKm;
  final double durationMinutes;
  final double pricePerKm;
  final double pricePerMinute;
  final double commissionRate; // e.g. 0.15 for 15%
  final double totalPrice;

  /// Optional currency label. Defaults to "ج.م".
  final String currency;

  const FareBreakdownCard({
    super.key,
    required this.baseFare,
    required this.distanceKm,
    required this.durationMinutes,
    required this.pricePerKm,
    required this.pricePerMinute,
    required this.commissionRate,
    required this.totalPrice,
    this.currency = 'ج.م',
  });

  @override
  Widget build(BuildContext context) {
    final distanceCost = distanceKm * pricePerKm;
    final timeCost = durationMinutes * pricePerMinute;
    final commission = totalPrice * commissionRate;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                  size: AppSpacing.iconMd,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'تفاصيل الأجرة',
                style: AppTextStyles.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Line items ──
          _FareRow(
            label: 'السعر الأساسي',
            detail: _fmtDetail(baseFare),
            value: baseFare,
            currency: currency,
          ),
          const SizedBox(height: AppSpacing.md),
          _FareRow(
            label: 'تكلفة المسافة',
            detail: '${_fmt(distanceKm)} كم × ${_fmt(pricePerKm)} $currency',
            value: distanceCost,
            currency: currency,
          ),
          const SizedBox(height: AppSpacing.md),
          _FareRow(
            label: 'تكلفة الوقت',
            detail:
                '${_fmt(durationMinutes)} د × ${_fmt(pricePerMinute)} $currency',
            value: timeCost,
            currency: currency,
          ),
          const SizedBox(height: AppSpacing.md),
          _FareRow(
            label: 'عمولة المنصة',
            detail: '${(commissionRate * 100).toStringAsFixed(0)}%',
            value: commission,
            valueColor: AppColors.warning,
            currency: currency,
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),

          // ── Total (prominent) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'السعر الإجمالي',
                style: AppTextStyles.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmt(totalPrice),
                    style: AppTextStyles.displaySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      currency,
                      style: AppTextStyles.bodyMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double value) => value.toStringAsFixed(2);

  String _fmtDetail(double value) => '${_fmt(value)} $currency';
}

/// A single labelled row: label + sub-detail on the left, value on the right.
class _FareRow extends StatelessWidget {
  final String label;
  final String detail;
  final double value;
  final Color? valueColor;
  final String currency;

  const _FareRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.currency,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: AppTextStyles.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)} $currency',
          style: AppTextStyles.titleSmall?.copyWith(
            color: valueColor ?? AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
