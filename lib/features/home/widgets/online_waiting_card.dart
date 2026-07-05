import 'package:flutter/material.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';
import 'radar_painter.dart';

/// Enhanced online waiting card with radar animation.
///
/// Shown when the captain is online and waiting for ride requests.
/// Features:
/// - Pulsing radar/sonar scanning animation
/// - Glass-morphism design with green glow border
/// - Animated "listening" dots
/// - Quick stats row (earnings today + trips count)
/// - Sound toggle button
class OnlineWaitingCard extends StatefulWidget {
  final double? todayEarnings;
  final int? todayTrips;
  final bool isSoundEnabled;
  final VoidCallback? onSoundToggle;

  const OnlineWaitingCard({
    super.key,
    this.todayEarnings,
    this.todayTrips,
    this.isSoundEnabled = true,
    this.onSoundToggle,
  });

  @override
  State<OnlineWaitingCard> createState() => _OnlineWaitingCardState();
}

class _OnlineWaitingCardState extends State<OnlineWaitingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;
  late final Animation<double> _radarRotation;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _radarRotation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(parent: _radarController, curve: Curves.linear));

    _pulseScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _radarController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'مستعد لاستقبال الطلبات - في انتظار طلب جديد',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderRow(),
              if (widget.todayEarnings != null ||
                  widget.todayTrips != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildStatsRow(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        _RadarWidget(rotation: _radarRotation, pulseScale: _pulseScale),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'مستعد لاستقبال الطلبات',
                style: AppTextStyles.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              _ListeningDots(controller: _radarController),
            ],
          ),
        ),
        _SoundToggle(
          isEnabled: widget.isSoundEnabled,
          onTap: widget.onSoundToggle,
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        if (widget.todayEarnings != null)
          Expanded(
            child: _StatItem(
              icon: Icons.trending_up_rounded,
              label: 'أرباح اليوم',
              value: '${widget.todayEarnings!.toStringAsFixed(0)} ج.م',
            ),
          ),
        if (widget.todayEarnings != null && widget.todayTrips != null)
          Container(
            width: 1,
            height: 32,
            color: AppColors.border.withValues(alpha: 0.5),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
        if (widget.todayTrips != null)
          Expanded(
            child: _StatItem(
              icon: Icons.directions_car_rounded,
              label: 'عدد الرحلات',
              value: '${widget.todayTrips}',
            ),
          ),
      ],
    );
  }
}

/// Radar scanning widget using [RadarPainter].
class _RadarWidget extends StatelessWidget {
  final Animation<double> rotation;
  final Animation<double> pulseScale;

  const _RadarWidget({required this.rotation, required this.pulseScale});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: rotation,
      builder: (context, _) {
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: CustomPaint(
            painter: RadarPainter(
              rotation: rotation.value,
              pulseScale: pulseScale.value,
            ),
          ),
        );
      },
    );
  }
}

/// Animated listening dots that pulse to indicate the app is listening
/// for ride requests.
class _ListeningDots extends StatefulWidget {
  final AnimationController controller;

  const _ListeningDots({required this.controller});

  @override
  State<_ListeningDots> createState() => _ListeningDotsState();
}

class _ListeningDotsState extends State<_ListeningDots> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final t = (widget.controller.value - delay) % 1.0;
            final opacity = (t < 0.5) ? t * 2 : (1 - t) * 2;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(
                  alpha: opacity.clamp(0.2, 1.0),
                ),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

/// Sound toggle icon button.
class _SoundToggle extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback? onTap;

  const _SoundToggle({required this.isEnabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isEnabled ? 'كتم الصوت' : 'تشغيل الصوت',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.cardElevated,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: isEnabled ? AppColors.success : AppColors.textMuted,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// A single stat item showing an icon, label, and value.
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
