import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final String? distance;
  final String? etaText;
  final VoidCallback onMarkArrived;
  final VoidCallback onMarkStarted;
  final VoidCallback onMarkCompleted;
  final VoidCallback onBackToHome;
  final VoidCallback? onOpenChat;

  const TripStatusCard({
    super.key,
    this.status,
    this.tripDoc,
    this.pickupAddress,
    this.destinationAddress,
    this.price,
    this.riderName,
    this.distance,
    this.etaText,
    required this.onMarkArrived,
    required this.onMarkStarted,
    required this.onMarkCompleted,
    required this.onBackToHome,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'accepted':
        return _AcceptedCard(
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
          onMarkArrived: onMarkArrived,
          onOpenChat: onOpenChat,
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
// ACCEPTED — captain heading to pickup
// ═══════════════════════════════════════════════════════════════

class _AcceptedCard extends StatelessWidget {
  final String riderName;
  final String pickup;
  final String destination;
  final String price;
  final String distance;
  final String? etaText;
  final VoidCallback onMarkArrived;
  final VoidCallback? onOpenChat;

  const _AcceptedCard({
    required this.riderName,
    required this.pickup,
    required this.destination,
    required this.price,
    required this.distance,
    this.etaText,
    required this.onMarkArrived,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return _TripCardContainer(
      borderColor: AppColors.primary.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderRow(
            riderName: riderName,
            badgeIcon: Icons.directions_walk,
            badgeText: 'متجه إليك',
            badgeColor: AppColors.primary,
          ),
          const SizedBox(height: 14),
          _PickupRow(address: pickup),
          const SizedBox(height: 8),
          _DestinationRow(address: destination),
          const SizedBox(height: 14),
          _FareDistanceRow(distance: distance, price: price),
          if (etaText != null) _EtaRow(etaText: etaText!),
          const SizedBox(height: 16),
          if (onOpenChat != null) _ChatButton(onOpenChat: onOpenChat!),
          if (onOpenChat != null) const SizedBox(height: 10),
          _ActionButton(
            label: '✅ وصلت',
            color: AppColors.success,
            onPressed: onMarkArrived,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ARRIVED — captain waiting at pickup
// ═══════════════════════════════════════════════════════════════

class _ArrivedCard extends StatelessWidget {
  final String riderName;
  final String destination;
  final String price;
  final VoidCallback onMarkStarted;
  final VoidCallback? onOpenChat;

  const _ArrivedCard({
    required this.riderName,
    required this.destination,
    required this.price,
    required this.onMarkStarted,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return _TripCardContainer(
      borderColor: AppColors.info.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderRow(
            riderName: riderName,
            badgeIcon: Icons.access_time,
            badgeText: 'في الانتظار',
            badgeColor: AppColors.info,
          ),
          const SizedBox(height: 14),
          _DestinationRow(address: destination),
          const SizedBox(height: 16),
          _FareRow(price: price),
          const SizedBox(height: 16),
          if (onOpenChat != null) _ChatButton(onOpenChat: onOpenChat!),
          if (onOpenChat != null) const SizedBox(height: 10),
          _ActionButton(
            label: '🚗 بدأت الرحلة',
            color: AppColors.primary,
            onPressed: onMarkStarted,
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
  final VoidCallback? onOpenChat;

  const _StartedCard({
    required this.riderName,
    required this.pickup,
    required this.destination,
    required this.price,
    required this.distance,
    this.etaText,
    required this.onMarkCompleted,
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
          if (onOpenChat != null) _ChatButton(onOpenChat: onOpenChat!),
          if (onOpenChat != null) const SizedBox(height: 10),
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
