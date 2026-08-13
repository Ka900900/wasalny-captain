import 'dart:async';

import 'package:flutter/material.dart';

import 'package:waslny_captain/core/services/sound_service.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// بطاقة طلب الرحلة الواردة (قبل القبول فقط).
///
/// تعرض بوضوح:
/// - الهيدر: نقطة خضراء + «طلب رحلة جديد» + عداد دائري + اسم الراكب
/// - المسار: من ← خط ربط ← إلى
/// - شيبس معلومات (نوع الرحلة / المسافة / المدة التقديرية)
/// - صندوق السعر (قيمة الرحلة الحقيقية)
/// - زرّا رفض / قبول الرحلة فقط (لا أزرار اتصال/محادثة)
///
/// العداد الذاتي: فقط هذا الويدجت يُعاد بناؤه كل ثانية بدل الشاشة كاملة.
class RideRequestCard extends StatefulWidget {
  final String? pickupAddress;
  final String? destinationAddress;
  final String? price; // قيمة الرحلة المنسّقة (ج.م)
  final String? riderName;
  final String? vehicleType; // لتحديد شيب نوع الرحلة
  final String? distance; // نص مثل "3.2 كم"
  final String? etaText; // نص مثل "5 دقائق"
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onExpired;

  const RideRequestCard({
    super.key,
    this.pickupAddress,
    this.destinationAddress,
    this.price,
    this.riderName,
    this.vehicleType,
    this.distance,
    this.etaText,
    required this.onAccept,
    required this.onReject,
    this.onExpired,
  });

  @override
  State<RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<RideRequestCard> {
  static const int _totalSeconds = 15;
  int _countdownSeconds = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // أوقف صوت تنبيه الرحلة المتكرر فوراً عند إزالة الكارت (قبول/رفض/انتهاء
    // العداد/أي مسار يُخفي الكارت) لضمان عدم استمرار الصوت بعد تفاعل الكابتن.
    SoundService.instance.stopAlert();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_countdownSeconds <= 1) {
        _timer?.cancel();
        _timer = null;
        widget.onExpired?.call();
        widget.onReject();
      } else {
        setState(() => _countdownSeconds--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double countdownValue = _countdownSeconds / _totalSeconds;
    final Color countdownColor = _countdownSeconds <= 5
        ? AppColors.error
        : AppColors.primary;

    final String rideType = _rideTypeLabel(widget.vehicleType);

    return Semantics(
      label: 'طلب رحلة جديد',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.shadowMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 1) Header: green dot + title + countdown + rider ──
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'طلب رحلة جديد',
                    style: AppTextStyles.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Semantics(
                  label: 'الوقت المتبقي: $_countdownSeconds ثانية',
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: countdownValue,
                          strokeWidth: 3.5,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            countdownColor,
                          ),
                        ),
                        Text(
                          '$_countdownSeconds',
                          style: TextStyle(
                            color: countdownColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (widget.riderName == null || widget.riderName!.isEmpty)
                        ? 'راكب جديد'
                        : widget.riderName!,
                    style: AppTextStyles.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 2) Route: from → connector → to ──
            _RouteRow(
              icon: Icons.circle,
              iconColor: AppColors.primary,
              label: 'من:',
              address: widget.pickupAddress,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(width: 2, height: 14, color: AppColors.border),
            ),
            _RouteRow(
              icon: Icons.location_on,
              iconColor: AppColors.error,
              label: 'إلى:',
              address: widget.destinationAddress,
            ),
            const SizedBox(height: 14),

            // ── 3) Info chips (single row) ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (rideType.isNotEmpty)
                  _Chip(icon: Icons.directions_car_outlined, label: rideType),
                if (widget.distance != null && widget.distance!.isNotEmpty)
                  _Chip(icon: Icons.route, label: widget.distance!),
                if (widget.etaText != null && widget.etaText!.isNotEmpty)
                  _Chip(icon: Icons.schedule, label: widget.etaText!),
              ],
            ),
            const SizedBox(height: 14),

            // ── 4) Price box ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'قيمة الرحلة',
                    style: AppTextStyles.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        widget.price ?? '0',
                        style: AppTextStyles.amountLarge?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ج.م',
                        style: AppTextStyles.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 5) Buttons: reject (outlined) + accept (primary, wider) ──
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Semantics(
                    label: 'رفض الرحلة',
                    child: OutlinedButton(
                      onPressed: () {
                        _timer?.cancel();
                        _timer = null;
                        widget.onReject();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                      child: const Text(
                        'رفض',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Semantics(
                    label: 'قبول الرحلة',
                    child: ElevatedButton(
                      onPressed: () {
                        _timer?.cancel();
                        _timer = null;
                        widget.onAccept();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                      child: const Text(
                        'قبول الرحلة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget for outlined icon + text buttons (chat / call).
String _rideTypeLabel(String? type) {
  if (type == null || type.isEmpty) return '';
  const map = <String, String>{
    'private': 'ملاكي',
    'PRIVATE_CAR': 'ملاكي',
    'taxi': 'تاكسي',
    'TAXI': 'تاكسي',
    'scooter': 'سكوتر',
    'SCOOTER': 'سكوتر',
    'motorcycle': 'موتوسيكل',
    'MOTORCYCLE': 'موتوسيكل',
  };
  return map[type] ?? type;
}

/// Small info chip (icon + label) used in the single-row info strip.
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pickup / destination row with a leading icon, a short label and the address.
class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? address;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, color: iconColor, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address ?? '',
                style: AppTextStyles.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
