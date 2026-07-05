import 'package:flutter/material.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// ───────────────────────────────────────────────────────────────
/// Waslny Bottom Sheet — Reusable bottom sheet utilities.
/// ───────────────────────────────────────────────────────────────
///
/// Provides:
/// - [WaslnyBottomSheet.show] — A styled modal bottom sheet with drag handle
/// - [WaslnyBottomSheet.showScrollable] — Scrollable variant for long content
///
/// Usage:
/// ```dart
/// final result = await WaslnyBottomSheet.show(
///   context,
///   title: 'اختر وجهتك',
///   child: Column(...),
/// );
/// ```
class WaslnyBottomSheet {
  WaslnyBottomSheet._();

  /// Shows a standard modal bottom sheet with drag handle and title.
  ///
  /// Returns `null` if dismissed by swiping or tapping outside.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
    required Widget child,
    bool? useSafeArea,
    bool isDismissible = true,
    double? heightFactor,
    List<BoxShadow>? boxShadow,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      elevation: 0,
      useSafeArea: useSafeArea ?? false,
      builder: (_) => _WaslnyBottomSheetContent(
        title: title,
        subtitle: subtitle,
        heightFactor: heightFactor,
        boxShadow: boxShadow,
        child: child,
      ),
    );
  }

  /// Shows a scrollable modal bottom sheet.
  static Future<T?> showScrollable<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
    required Widget child,
    bool isDismissible = true,
    EdgeInsets? padding,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      elevation: 0,
      useSafeArea: false,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _WaslnyBottomSheetContent(
          title: title,
          subtitle: subtitle,
          scrollController: scrollController,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

// ─── Content Widget ────────────────────────────────────────────

class _WaslnyBottomSheetContent extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final ScrollController? scrollController;
  final double? heightFactor;
  final List<BoxShadow>? boxShadow;
  final EdgeInsets? padding;

  const _WaslnyBottomSheetContent({
    this.title,
    this.subtitle,
    required this.child,
    this.scrollController,
    this.heightFactor,
    this.boxShadow,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.only(top: heightFactor ?? 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radiusXxl),
          topRight: Radius.circular(AppSpacing.radiusXxl),
        ),
        boxShadow: boxShadow ?? AppColors.shadowLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle ─────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),

          // ── Title ───────────────────────────────────
          if (title != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                subtitle != null ? AppSpacing.xxs : AppSpacing.md,
              ),
              child: Text(
                title!,
                style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                0,
                AppSpacing.xxl,
                AppSpacing.lg,
              ),
              child: Text(
                subtitle!,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),

          // ── Content ─────────────────────────────────
          Expanded(
            child: scrollController != null
                ? ListView(
                    controller: scrollController,
                    padding:
                        padding ??
                        EdgeInsets.only(
                          left: AppSpacing.xxl,
                          right: AppSpacing.xxl,
                          bottom: bottomPadding + AppSpacing.lg,
                        ),
                    children: [child],
                  )
                : SingleChildScrollView(
                    padding:
                        padding ??
                        EdgeInsets.only(
                          left: AppSpacing.xxl,
                          right: AppSpacing.xxl,
                          bottom: bottomPadding + AppSpacing.lg,
                        ),
                    child: child,
                  ),
          ),
        ],
      ),
    );
  }
}
