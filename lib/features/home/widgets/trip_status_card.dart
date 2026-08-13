import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';

/// Active trip card that renders different layouts depending on
/// [_activeTripStatus] (`accepted`, `arrived`, `started`, `completed`).
class TripStatusCard extends StatelessWidget {
  final String? status;
  final DocumentSnapshot? tripDoc;
  final String? pickupAddress;
  final String? destinationAddress;
  final String? price;
  final String? riderName;
  final String? riderPhone;
  final double? riderRating;
  final int? riderRatingCount;
  final String? paymentMethod;
  final String? distance;
  final String? etaText;
  final VoidCallback onMarkArrived;
  final VoidCallback onMarkStarted;
  final VoidCallback onMarkCompleted;
  final VoidCallback onBackToHome;
  final VoidCallback? onCallTap;
  final VoidCallback? onOpenChat;
  final VoidCallback? onCancel;

  const TripStatusCard({
    super.key,
    this.status,
    this.tripDoc,
    this.pickupAddress,
    this.destinationAddress,
    this.price,
    this.riderName,
    this.riderPhone,
    this.riderRating,
    this.riderRatingCount,
    this.paymentMethod,
    this.distance,
    this.etaText,
    required this.onMarkArrived,
    required this.onMarkStarted,
    required this.onMarkCompleted,
    required this.onBackToHome,
    this.onCallTap,
    this.onOpenChat,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'accepted':
        return _AcceptedCard(
          riderName: riderName ?? tripDoc?['riderName'] as String? ?? '...',
          riderPhone: riderPhone ?? tripDoc?['riderPhone'] as String?,
          riderRating: riderRating,
          riderRatingCount: riderRatingCount,
          paymentMethod: paymentMethod,
          pickup:
              pickupAddress ?? tripDoc?['pickupAddress'] as String? ?? '...',
          destination:
              destinationAddress ??
              tripDoc?['destinationAddress'] as String? ??
              '...',
          price: price ?? tripDoc?['price'] as String? ?? '...',
          distance: distance ?? '',
          etaText: etaText,
          onMarkArrived: onMarkArrived,
          onOpenChat: onOpenChat,
          onCancel: onCancel,
        );
      case 'arrived':
        return _ArrivedCard(
          riderName: riderName ?? tripDoc?['riderName'] as String? ?? '...',
          destination:
              destinationAddress ??
              tripDoc?['destinationAddress'] as String? ??
              '...',
          price: price ?? tripDoc?['price'] as String? ?? '...',
          onMarkStarted: onMarkStarted,
          onCallTap: onCallTap,
          onOpenChat: onOpenChat,
        );
      case 'started':
        return _StartedCard(
          riderName: riderName ?? tripDoc?['riderName'] as String? ?? '...',
          pickup:
              pickupAddress ?? tripDoc?['pickupAddress'] as String? ?? '...',
          destination:
              destinationAddress ??
              tripDoc?['destinationAddress'] as String? ??
              '...',
          price: price ?? tripDoc?['price'] as String? ?? '...',
          distance: distance ?? '',
          etaText: etaText,
          onMarkCompleted: onMarkCompleted,
          onCallTap: onCallTap,
          onOpenChat: onOpenChat,
        );
      case 'completed':
        return _CompletedCard(
          riderName: riderName ?? tripDoc?['riderName'] as String? ?? '...',
          price: price ?? tripDoc?['price'] as String? ?? '...',
          distance: distance ?? '',
          onBackToHome: onBackToHome,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// ACCEPTED — captain heading to pickup (متوجه للراكب)
// ═══════════════════════════════════════════════════════════════

class _AcceptedCard extends StatelessWidget {
  final String riderName;
  final String? riderPhone;
  final double? riderRating;
  final int? riderRatingCount;
  final String? paymentMethod;
  final String pickup;
  final String destination;
  final String price;
  final String distance;
  final String? etaText;
  final VoidCallback onMarkArrived;
  final VoidCallback? onOpenChat;
  final VoidCallback? onCancel;

  const _AcceptedCard({
    required this.riderName,
    this.riderPhone,
    this.riderRating,
    this.riderRatingCount,
    this.paymentMethod,
    required this.pickup,
    required this.destination,
    required this.price,
    required this.distance,
    this.etaText,
    required this.onMarkArrived,
    this.onOpenChat,
    this.onCancel,
  });

  Future<void> _call() async {
    final phone = riderPhone;
    if (phone == null || phone.isEmpty) return;
    try {
      await launchUrl(Uri.parse('tel:$phone'));
    } catch (_) {
      // Silent — لا نعرض أخطاء على زر الاتصال.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasRating = riderRating != null;
    final bool hasPayment = paymentMethod != null && paymentMethod!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 1) شريط علوي أخضر كامل العرض ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppSpacing.radiusXl),
              topRight: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'متوجه للراكب',
                style: AppTextStyles.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'توجه إلى نقطة الالتقاط',
                style: AppTextStyles.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),

        // ── باقي البطاقة على خلفية داكنة مستديرة ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppSpacing.radiusXl),
              bottomRight: Radius.circular(AppSpacing.radiusXl),
            ),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.shadowMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 2) بطاقة الراكب ──
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          riderName,
                          style: AppTextStyles.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (hasRating) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: AppColors.warning,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                riderRating!.toStringAsFixed(1),
                                style: AppTextStyles.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (riderRatingCount != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '($riderRatingCount)',
                                  style: AppTextStyles.labelSmall?.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // صف زرّين متساويين بحدود خضراء
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _call,
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('اتصال'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('محادثة'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── 3) قسم نقطة الالتقاط ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نقطة الالتقاط',
                          style: AppTextStyles.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pickup,
                          style: AppTextStyles.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (distance.isNotEmpty || etaText != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (distance.isNotEmpty)
                                _InfoChip(icon: Icons.route, label: distance),
                              if (etaText != null)
                                _InfoChip(
                                  icon: Icons.access_time,
                                  label: etaText!,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── 4) الوجهة النهائية (ثانوية وأصغر) ──
              if (destination.isNotEmpty)
                Text(
                  'الوجهة النهائية: $destination',
                  style: AppTextStyles.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 16),

              // ── 5) السعر ──
              Center(
                child: Column(
                  children: [
                    Text(
                      price,
                      style: AppTextStyles.amountLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'ج.م',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (hasPayment) ...[
                      const SizedBox(height: 6),
                      Text(
                        paymentMethod!,
                        style: AppTextStyles.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── 6) الأزرار السفلية ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onMarkArrived,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  child: const Text(
                    'وصلت لنقطة الالتقاط',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: onCancel,
                    child: Text(
                      'إلغاء الرحلة',
                      style: AppTextStyles.labelMedium?.copyWith(
                        color: AppColors.error.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// شيب صغير (أيقونة + نص) يُستخدم في قسم نقطة الالتقاط.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ARRIVED — captain waiting at pickup
// ═══════════════════════════════════════════════════════════════

class _ArrivedCard extends StatefulWidget {
  final String riderName;
  final String destination;
  final String price;
  final VoidCallback onMarkStarted;
  final VoidCallback? onCallTap;
  final VoidCallback? onOpenChat;

  const _ArrivedCard({
    required this.riderName,
    required this.destination,
    required this.price,
    required this.onMarkStarted,
    this.onCallTap,
    this.onOpenChat,
  });

  @override
  State<_ArrivedCard> createState() => _ArrivedCardState();
}

/// حالة بطاقة «في الانتظار» — تعرض عداد انتظار 5 دقائق (مدة السماح قبل غرامة
/// التأخير 10 ج.م). العداد محلي في الـ UI فقط؛ الغرامة تُفرض من الباك إند
/// عبر `processDueLateFees` عند انقضاء المدة.
class _ArrivedCardState extends State<_ArrivedCard> {
  static const Duration _waitDuration = Duration(minutes: 5);

  late Duration _remaining = _waitDuration;
  Timer? _timer;

  bool get _expired => _remaining <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= Duration.zero) {
        _timer?.cancel();
        return;
      }
      setState(() => _remaining = _remaining - const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _remainingLabel {
    final m = _remaining.inMinutes;
    final s = _remaining.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return _TripCardContainer(
      borderColor: AppColors.info.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderRow(
            riderName: widget.riderName,
            badgeIcon: Icons.access_time,
            badgeText: 'في الانتظار',
            badgeColor: AppColors.info,
          ),
          const SizedBox(height: 14),
          _DestinationRow(address: widget.destination),
          const SizedBox(height: 16),
          _FareRow(price: widget.price),
          const SizedBox(height: 16),
          _WaitingCountdownRow(label: _remainingLabel, expired: _expired),
          const SizedBox(height: 16),
          if (widget.onCallTap != null || widget.onOpenChat != null)
            _ContactRow(
              onCall: widget.onCallTap,
              onOpenChat: widget.onOpenChat,
            ),
          if (widget.onCallTap != null || widget.onOpenChat != null)
            const SizedBox(height: 10),
          _ActionButton(
            label: '🚗 بدأت الرحلة',
            color: AppColors.primary,
            onPressed: widget.onMarkStarted,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STARTED — captain driving to destination
// ═══════════════════════════════════════════════════════════════

class _StartedCard extends StatelessWidget {
  final String riderName;
  final String pickup;
  final String destination;
  final String price;
  final String distance;
  final String? etaText;
  final VoidCallback onMarkCompleted;
  final VoidCallback? onCallTap;
  final VoidCallback? onOpenChat;

  const _StartedCard({
    required this.riderName,
    required this.pickup,
    required this.destination,
    required this.price,
    required this.distance,
    this.etaText,
    required this.onMarkCompleted,
    this.onCallTap,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return _TripCardContainer(
      borderColor: AppColors.error.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderRow(
            riderName: riderName,
            badgeIcon: Icons.directions_car,
            badgeText: 'متجه للوجهة',
            badgeColor: AppColors.error,
          ),
          const SizedBox(height: 14),
          _PickupRow(address: pickup),
          const SizedBox(height: 8),
          _DestinationRow(address: destination),
          const SizedBox(height: 14),
          _FareDistanceRow(distance: distance, price: price),
          if (etaText != null) _EtaRow(etaText: etaText!),
          const SizedBox(height: 16),
          if (onCallTap != null || onOpenChat != null)
            _ContactRow(onCall: onCallTap, onOpenChat: onOpenChat),
          if (onCallTap != null || onOpenChat != null)
            const SizedBox(height: 10),
          _ActionButton(
            label: '✅ أكملت',
            color: AppColors.success,
            onPressed: onMarkCompleted,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COMPLETED — ride finished
// ═══════════════════════════════════════════════════════════════

class _CompletedCard extends StatelessWidget {
  final String riderName;
  final String price;
  final String distance;
  final VoidCallback onBackToHome;

  const _CompletedCard({
    required this.riderName,
    required this.price,
    required this.distance,
    required this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    return _TripCardContainer(
      borderColor: AppColors.primary.withValues(alpha: 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: 48,
          ),
          const SizedBox(height: 8),
          const Text(
            'تمت الرحلة بنجاح',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monetization_on,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                '$price ج.م',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (distance.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              distance,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 4),
              Text(
                riderName,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ActionButton(
            label: 'العودة للرئيسية',
            color: AppColors.primary,
            onPressed: onBackToHome,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared sub‑widgets
// ═══════════════════════════════════════════════════════════════

/// Outer container for all trip cards.
class _TripCardContainer extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _TripCardContainer({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// Rider name + status badge row.
class _HeaderRow extends StatelessWidget {
  final String riderName;
  final IconData badgeIcon;
  final String badgeText;
  final Color badgeColor;

  const _HeaderRow({
    required this.riderName,
    required this.badgeIcon,
    required this.badgeText,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.person, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            riderName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, color: badgeColor, size: 14),
              const SizedBox(width: 4),
              Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pickup address row.
class _PickupRow extends StatelessWidget {
  final String address;

  const _PickupRow({required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.circle, color: AppColors.primary, size: 12),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Destination address row.
class _DestinationRow extends StatelessWidget {
  final String address;

  const _DestinationRow({required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: AppColors.error, size: 12),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fare-only row (used in arrived card).
class _FareRow extends StatelessWidget {
  final String price;

  const _FareRow({required this.price});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.monetization_on, color: AppColors.textMuted, size: 14),
        const SizedBox(width: 4),
        Text(
          '$price ج.م',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Distance + fare row.
class _FareDistanceRow extends StatelessWidget {
  final String distance;
  final String price;

  const _FareDistanceRow({required this.distance, required this.price});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (distance.isNotEmpty) ...[
          const Icon(Icons.route, color: AppColors.textMuted, size: 14),
          const SizedBox(width: 4),
          Text(
            distance,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(width: 16),
        ],
        const Icon(Icons.monetization_on, color: AppColors.textMuted, size: 14),
        const SizedBox(width: 4),
        Text(
          '$price ج.م',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// ETA row.
class _EtaRow extends StatelessWidget {
  final String etaText;

  const _EtaRow({required this.etaText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: AppColors.warning, size: 14),
          const SizedBox(width: 4),
          Text(
            etaText,
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width action button used in all trip cards.
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chat button shown on active trip cards — opens the real-time chat.
class _ChatButton extends StatelessWidget {
  final VoidCallback onOpenChat;

  const _ChatButton({required this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onOpenChat,
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: const Text('محادثة الراكب'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }
}

/// Call button — يفتح طلب اتصال `tel:` برقم الراكب عبر `url_launcher`
/// (محلي 100% — لا يُستدعى أي API للاتصال).
class _CallButton extends StatelessWidget {
  final VoidCallback onCall;

  const _CallButton({required this.onCall});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onCall,
        icon: const Icon(Icons.phone_outlined, size: 18),
        label: const Text('اتصال'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.success,
          side: BorderSide(color: AppColors.success.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }
}

/// صف تواصل: زر اتصال + زر محادثة جنباً إلى جنب (أو أحدهما فقط بعرض كامل).
class _ContactRow extends StatelessWidget {
  final VoidCallback? onCall;
  final VoidCallback? onOpenChat;

  const _ContactRow({this.onCall, this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    if (onCall == null && onOpenChat == null) return const SizedBox.shrink();

    final List<Widget> children = [];
    if (onCall != null) {
      children.add(Expanded(child: _CallButton(onCall: onCall!)));
    }
    if (onOpenChat != null) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 10));
      children.add(Expanded(child: _ChatButton(onOpenChat: onOpenChat!)));
    }
    return Row(children: children);
  }
}

/// عداد مدة الانتظار (5 دقائق) — يُعرض في بطاقة «في الانتظار».
class _WaitingCountdownRow extends StatelessWidget {
  final String label;
  final bool expired;

  const _WaitingCountdownRow({required this.label, required this.expired});

  @override
  Widget build(BuildContext context) {
    final Color color = expired ? AppColors.error : AppColors.info;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            expired ? Icons.timer_off_outlined : Icons.timer_outlined,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired ? 'انتهت مدة الانتظار' : 'مدة الانتظار المتبقية',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!expired)
                  Text(
                    'بعد انتهاء المدة قد تُطبَّق غرامة تأخير (10 ج.م)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
