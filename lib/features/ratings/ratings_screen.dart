import 'package:flutter/material.dart';
import 'package:waslny_captain/core/models/rating.dart';
import 'package:waslny_captain/core/repositories/ratings_repository.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  bool _loading = true;
  String? _error;
  RatingsResult? _data;

  @override
  void initState() {
    super.initState();
    _fetchRatings();
  }

  Future<void> _fetchRatings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await RatingsRepository.instance.fetchRatings();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'تعذر تحميل التقييمات، تحقق من اتصالك وحاول مجدداً',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBg,
        elevation: 0,
        title: const Text('تقييمات العملاء'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchRatings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data;
    if (data == null || data.ratings.isEmpty) {
      return const Center(
        child: Text(
          'لسه معندكش تقييمات',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── Summary header ──
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.warning,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                data.averageRating.toStringAsFixed(1),
                style: AppTextStyles.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '(${data.totalRatings} تقييم)',
                style: AppTextStyles.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // ── Ratings list ──
        ...data.ratings.map((r) => _ratingCard(r)),
      ],
    );
  }

  Widget _ratingCard(Rating r) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 5),
              Text(
                r.rating.toString(),
                style: AppTextStyles.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Expanded(
                child: Text(
                  r.fromUserName,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (r.rideRoute.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.rideRoute,
              style: AppTextStyles.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            r.comment?.isNotEmpty == true ? r.comment! : 'لا يوجد تعليق',
            style: AppTextStyles.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
