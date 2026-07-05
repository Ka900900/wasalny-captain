import 'dart:async';

import 'package:flutter/material.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';

/// Ride request card shown when a new pending ride arrives.
///
/// Displays:
/// - Countdown timer (circular progress) — managed internally to avoid
///   forcing parent rebuilds on every tick.
/// - Fare (prominent)
/// - Pickup address
/// - Destination address
/// - Rider name + trip distance
/// - Accept / Reject buttons
///
/// The countdown timer is self-contained: only this widget rebuilds
/// each second instead of the entire parent screen.
class RideRequestCard extends StatefulWidget {
  final String? pickupAddress;
  final String? destinationAddress;
  final String? price;
  final String? riderName;
  final String? distance;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onExpired;

  const RideRequestCard({
    super.key,
    this.pickupAddress,
    this.destinationAddress,
    this.price,
    this.riderName,
    this.distance,
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

    return Semantics(
      label: 'طلب رحلة جديد',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: AppColors.shadowMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header: Countdown · Title · Fare ──
            Row(
              children: [
                // Circular countdown
                Semantics(
                  label: 'الوقت المتبقي: $_countdownSeconds ثانية',
                  child: SizedBox(
                    width: 44,
                    height: 44,
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Text(
                    'طلب جديد!',
                    style: AppTextStyles.headlineSmall?.copyWith(
                      color: AppColors.primaryBg,
                    ),
                  ),
                ),
                // Fare
                Semantics(
                  label: 'قيمة الرحلة: ${widget.price} جنيه',
                    child: Text(
                      widget.price ?? '',
                      style: AppTextStyles.titleLarge?.copyWith(
                        color: AppColors.primaryBg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Pickup ──
            _AddressRow(
              icon: Icons.circle,
              iconColor: AppColors.primary,
              address: widget.pickupAddress,
            ),
            const SizedBox(height: 8),

            // ── Destination ──
            _AddressRow(
              icon: Icons.location_on,
              iconColor: AppColors.error,
              address: widget.destinationAddress,
            ),
            const SizedBox(height: 10),

            // ── Rider name + Distance ──
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.riderName ?? '',
                  style: AppTextStyles.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (widget.distance != null) ...[
                  const SizedBox(width: 20),
                  Icon(Icons.route, color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    widget.distance!,
                    style: AppTextStyles.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),

            // ── Accept / Reject ──
            Row(
              children: [
                Expanded(
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
                        foregroundColor: AppColors.bg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                      child: const Text(
                        'قبول',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: 'رفض الرحلة',
                    child: ElevatedButton(
                      onPressed: () {
                        _timer?.cancel();
                        _timer = null;
                        widget.onReject();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
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
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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

/// Small helper for pickup / destination rows.
class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String? address;

  const _AddressRow({
    required this.icon,
    required this.iconColor,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 12),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
