import 'package:flutter/material.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// A shimmer loading placeholder that mimics a card or line.
///
/// Usage:
/// ```dart
/// WaslnyShimmer(
///   width: double.infinity,
///   height: 100,
///   borderRadius: 16,
/// )
/// ```
class WaslnyShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const WaslnyShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = AppSpacing.radiusMd,
  });

  @override
  State<WaslnyShimmer> createState() => _WaslnyShimmerState();
}

class _WaslnyShimmerState extends State<WaslnyShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: const [AppColors.card, AppColors.border, AppColors.card],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
            ),
          ),
        );
      },
    );
  }
}

/// A convenience widget that shows a column of shimmer lines,
/// useful for list loading states.
class WaslnyShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double spacing;

  const WaslnyShimmerList({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 80,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: WaslnyShimmer(height: itemHeight),
        ),
      ),
    );
  }
}
