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
  final String? riderId;
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
  final void Function(RiderRatingSubmission)? onRateRider;
  final VoidCallback? onSkipRating;
  final VoidCallback? onSupport;

  const TripStatusCard({
    super.key,
    this.status,
    this.tripDoc,
    this.pickupAddress,
    this.destinationAddress,
    this.price,
    this.riderName,
    this.riderPhone,
    this.riderId,
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
    this.onRateRider,
    this.onSkipRating,
    this.onSupport,
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
          onCancel: onCancel,
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
          paymentMethod: paymentMethod,
          distance: distance ?? '',
          etaText: etaText,
          onMarkCompleted: onMarkCompleted,
          onCallTap: onCallTap,
          onOpenChat: onOpenChat,
          onSupport: onSupport,
        );
      case 'completed':
        return _CompletedCard(
          riderName: riderName ?? tripDoc?['riderName'] as String? ?? '...',
          riderId: riderId ?? tripDoc?['riderId'] as String?,
          price: price ?? tripDoc?['price'] as String? ?? '...',
          paymentMethod: paymentMethod,
          distance: distance ?? '',
          onRateRider: onRateRider,
          onSkipRating: onSkipRating,
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
  final VoidCallback? onCancel;

  const _ArrivedCard({
    required this.riderName,
    required this.destination,
    required this.price,
    required this.onMarkStarted,
    this.onCallTap,
    this.onOpenChat,
    this.onCancel,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 1) شريط علوي برتقالي كامل العرض ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.warning,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppSpacing.radiusXl),
              topRight: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'في انتظار الراكب',
                style: AppTextStyles.headlineSmall?.copyWith(
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'العد التنازلي قبل تطبيق غرامة التأخير',
                style: AppTextStyles.bodySmall?.copyWith(color: Colors.black54),
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
              // ── 2) صف الراكب: أفاتار/اسم + اتصال + محادثة ──
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.warning,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.riderName,
                      style: AppTextStyles.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (widget.onCallTap != null)
                    _CircleIconButton(
                      icon: Icons.phone_outlined,
                      color: AppColors.primary,
                      onPressed: widget.onCallTap!,
                    ),
                  if (widget.onOpenChat != null) ...[
                    const SizedBox(width: 8),
                    _CircleIconButton(
                      icon: Icons.chat_bubble_outline,
                      color: AppColors.primary,
                      onPressed: widget.onOpenChat!,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── 3) عداد كبير في المنتصف (مدة الانتظار المتبقية) ──
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _remainingLabel,
                    style: AppTextStyles.amountMedium?.copyWith(
                      color: AppColors.warning,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── 4) تنويه الغرامة ──
              Center(
                child: Text(
                  'بعد انتهاء المدة قد تُطبَّق غرامة تأخير (10 ج.م)',
                  style: AppTextStyles.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // ── 5) الوجهة النهائية ثانوية + الأجرة ──
              _DestinationRow(address: widget.destination),
              const SizedBox(height: 10),
              _FareRow(price: widget.price),
              const SizedBox(height: 18),

              // ── 6) زر رئيسي أخضر: «بدأت الرحلة» ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.onMarkStarted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  child: const Text(
                    'بدأت الرحلة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (widget.onCancel != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: widget.onCancel,
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

/// زر دائري صغير (اتصال/محادثة) يُستخدم في صف الراكب.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 20),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
  final String? paymentMethod;
  final String distance;
  final String? etaText;
  final VoidCallback onMarkCompleted;
  final VoidCallback? onCallTap;
  final VoidCallback? onOpenChat;
  final VoidCallback? onSupport;

  const _StartedCard({
    required this.riderName,
    required this.pickup,
    required this.destination,
    required this.price,
    this.paymentMethod,
    required this.distance,
    this.etaText,
    required this.onMarkCompleted,
    this.onCallTap,
    this.onOpenChat,
    this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPayment = paymentMethod != null && paymentMethod!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 1) شريط علوي (أزرق/تيل) ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.info,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppSpacing.radiusXl),
              topRight: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الرحلة جارية',
                style: AppTextStyles.headlineSmall?.copyWith(
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'في الطريق إلى الوجهة',
                style: AppTextStyles.bodySmall?.copyWith(color: Colors.black54),
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
              // ── 2) صف مضغوط: الراكب + اتصال + محادثة ──
              Row(
                children: [
                  const Icon(
                    Icons.person,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      riderName,
                      style: AppTextStyles.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (onCallTap != null)
                    _CircleIconButton(
                      icon: Icons.phone_outlined,
                      color: AppColors.info,
                      onPressed: onCallTap!,
                    ),
                  if (onOpenChat != null) ...[
                    const SizedBox(width: 8),
                    _CircleIconButton(
                      icon: Icons.chat_bubble_outline,
                      color: AppColors.info,
                      onPressed: onOpenChat!,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // ── 3) قسم الوجهة بارز ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.infoContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الوجهة',
                      style: AppTextStyles.labelSmall?.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destination,
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
                            _InfoChip(icon: Icons.access_time, label: etaText!),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── 4) صندوق المبلغ: السعر + طريقة الدفع ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الأجرة',
                          style: AppTextStyles.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$price ج.م',
                          style: AppTextStyles.titleMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (hasPayment)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Text(
                          paymentMethod!,
                          style: AppTextStyles.labelSmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── 5) زر رئيسي: «إنهاء الرحلة» ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onMarkCompleted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  child: const Text(
                    'إنهاء الرحلة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (onSupport != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: onSupport,
                    icon: const Icon(Icons.support_agent, size: 18),
                    label: const Text('مشكلة / دعم'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
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

// ═══════════════════════════════════════════════════════════════
// COMPLETED — ride finished
// ═══════════════════════════════════════════════════════════════

/// بيانات تقييم الراكب المجمّعة من كارت «تقييم الراكب».
class RiderRatingSubmission {
  final int rating;
  final List<String> tags;
  final String note;

  const RiderRatingSubmission({
    required this.rating,
    required this.tags,
    required this.note,
  });
}

class _CompletedCard extends StatefulWidget {
  final String riderName;
  final String? riderId;
  final String price;
  final String? paymentMethod;
  final String distance;
  final void Function(RiderRatingSubmission)? onRateRider;
  final VoidCallback? onSkipRating;

  const _CompletedCard({
    required this.riderName,
    this.riderId,
    required this.price,
    this.paymentMethod,
    required this.distance,
    this.onRateRider,
    this.onSkipRating,
  });

  @override
  State<_CompletedCard> createState() => _CompletedCardState();
}

/// كارت «تقييم الراكب» — يُعرض بعد نجاح إنهاء الرحلة لإغلاق الدائرة.
/// التقييم (نجوم + أوصاف + ملاحظة) يُجمَع محلياً ثم يُمرَّر عبر [onRateRider]
/// الذي يستدعي endpoint التقييم في الباك (`POST /rate`). «تخطي» يُغلق الرحلة
/// بدون تقييم. بعد الإرسال أو التخطّي يمسح [home_screen] الحالة النشطة.
class _CompletedCardState extends State<_CompletedCard> {
  int _rating = 0;
  final Set<String> _selectedTags = {};
  final TextEditingController _noteController = TextEditingController();

  static const List<String> _quickTags = ['محترم', 'ملتزم بالوقت', 'تعامل جيد'];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPayment =
        widget.paymentMethod != null && widget.paymentMethod!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 1) شريط أخضر ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                'تم إنهاء الرحلة',
                style: AppTextStyles.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'قيم الراكب لإغلاق الرحلة',
                style: AppTextStyles.bodySmall?.copyWith(
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
              // ── 2) اسم الراكب + أفاتار ──
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.riderName,
                      style: AppTextStyles.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── 3) اختيار 1–5 نجوم (إلزامي) ──
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return IconButton(
                      onPressed: () => setState(() => _rating = star),
                      icon: Icon(
                        star <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: AppColors.warning,
                        size: 36,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),

              // ── 4) أوصاف سريعة اختيارية (chips) ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickTags.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return ChoiceChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    }),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: AppTextStyles.labelMedium?.copyWith(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // ── 5) حقل ملاحظة اختياري ──
              TextField(
                controller: _noteController,
                maxLines: 2,
                style: AppTextStyles.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'ملاحظة (اختياري)',
                  hintStyle: AppTextStyles.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── 6) ملخص الأجرة + طريقة الدفع ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الأجرة',
                          style: AppTextStyles.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.price} ج.م',
                          style: AppTextStyles.titleMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (hasPayment)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Text(
                          widget.paymentMethod!,
                          style: AppTextStyles.labelSmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── 7) زر «إرسال التقييم» ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _rating == 0
                      ? null
                      : () {
                          widget.onRateRider?.call(
                            RiderRatingSubmission(
                              rating: _rating,
                              tags: _selectedTags.toList(),
                              note: _noteController.text.trim(),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  child: const Text(
                    'إرسال التقييم',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── 8) «تخطي» ──
              Center(
                child: TextButton(
                  onPressed: widget.onSkipRating,
                  child: Text(
                    'تخطي',
                    style: AppTextStyles.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared sub‑widgets
// ═══════════════════════════════════════════════════════════════

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
