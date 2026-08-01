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
/// - Chat / Call buttons (التواصل مع الراكب)
/// - Accept / Reject buttons
///
/// The countdown timer is self-contained: only this widget rebuilds
/// each second instead of the entire parent screen.
class RideRequestCard extends StatefulWidget {
  final String? pickupAddress;
  final String? destinationAddress;
  final String? price;
  final String? riderName;
  final String? riderPhone;
  final String? distance;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onExpired;
  final VoidCallback? onChatTap;
  final VoidCallback? onCallTap;

  const RideRequestCard({
    super.key,
    this.pickupAddress,
    this.destinationAddress,
    this.price,
    this.riderName,
    this.riderPhone,
    this.distance,
    required this.onAccept,
    required this.onReject,
    this.onExpired,
    this.onChatTap,
    this.onCallTap,
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

  /// عرض حوار قبول/رفض عند الضغط على الكارت نفسه.
  void _showAcceptRejectDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Row(
          children: [
            Icon(Icons.directions_car, color: AppColors.neonGreen, size: 24),
            const SizedBox(width: 8),
            const Text('طلب رحلة', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.pickupAddress != null &&
                widget.pickupAddress!.isNotEmpty) ...[
              _DialogRow(
                icon: Icons.circle,
                iconColor: AppColors.primary,
                text: widget.pickupAddress!,
              ),
              const SizedBox(height: 8),
            ],
            if (widget.destinationAddress != null &&
                widget.destinationAddress!.isNotEmpty) ...[
              _DialogRow(
                icon: Icons.location_on,
                iconColor: AppColors.error,
                text: widget.destinationAddress!,
              ),
              const SizedBox(height: 8),
            ],
            if (widget.price != null && widget.price!.isNotEmpty)
              Text(
                'قيمة الرحلة: ${widget.price} جنيه',
                style: const TextStyle(
                  color: AppColors.neonGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (widget.distance != null && widget.distance!.isNotEmpty)
              Text(
                'المسافة: ${widget.distance}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onReject();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('رفض', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onAccept();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonGreen,
              foregroundColor: Colors.black,
            ),
            child: const Text('قبول', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double countdownValue = _countdownSeconds / _totalSeconds;
    final Color countdownColor = _countdownSeconds <= 5
        ? AppColors.error
        : AppColors.primary;

    return GestureDetector(
      onTap: _showAcceptRejectDialog,
      child: Semantics(
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
                    (widget.riderName == null || widget.riderName!.isEmpty)
                        ? 'عميل'
                        : widget.riderName!,
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
              const SizedBox(height: 14),

              // ── Chat / Call buttons (التواصل مع الراكب) ──
              Row(
                children: [
                  if (widget.onChatTap != null)
                    Expanded(
                      child: _OutlinedIconButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'محادثة',
                        onTap: widget.onChatTap!,
                      ),
                    ),
                  if (widget.onChatTap != null && widget.onCallTap != null)
                    const SizedBox(width: 10),
                  if (widget.onCallTap != null)
                    Expanded(
                      child: _OutlinedIconButton(
                        icon: Icons.phone_outlined,
                        label: 'اتصال',
                        onTap: widget.onCallTap!,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

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
      ),
    );
  }
}

/// Helper widget for outlined icon + text buttons (chat / call).
class _OutlinedIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlinedIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBg,
          side: BorderSide(color: AppColors.primaryBg.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }
}

/// Helper widget for dialog rows (pickup / destination).
class _DialogRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _DialogRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
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
