import 'package:flutter/material.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// Waslny Button â€” Primary action button with multiple variants.
/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
///
/// Variants:
/// - `primary`  â€” Solid green (default), full-width, elevated
/// - `secondary` â€” Filled tonal (dark surface)
/// - `outline`  â€” Bordered with no fill
/// - `ghost`    â€” No border, no fill, just text
/// - `danger`   â€” Red background for destructive actions
/// - `text`     â€” Plain text link style
///
/// Loading state shows a pulsing [CircularProgressIndicator].
///
/// Usage:
/// ```dart
/// WaslnyButton.primary(label: 'ØªØ£ÙƒÙŠØ¯', onPressed: () {});
/// WaslnyButton.outline(label: 'Ø¥Ù„ØºØ§Ø¡', onPressed: () {});
/// WaslnyButton.primary(label: '...', loading: true, onPressed: null);
/// ```
class WaslnyButton extends StatelessWidget {
  // â”€â”€ Variant constructors â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  const WaslnyButton._({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = WaslnyButtonVariant.primary,
    this.size = WaslnyButtonSize.lg,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.iconPosition = WaslnyIconPosition.start,
  });

  /// Solid green primary button (default).
  const WaslnyButton.primary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    WaslnyButtonSize size = WaslnyButtonSize.lg,
    IconData? icon,
    bool loading = false,
    bool expanded = true,
    WaslnyIconPosition iconPosition = WaslnyIconPosition.start,
  }) : this._(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: WaslnyButtonVariant.primary,
         size: size,
         icon: icon,
         loading: loading,
         expanded: expanded,
         iconPosition: iconPosition,
       );

  /// Filled tonal button (dark surface background).
  const WaslnyButton.secondary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    WaslnyButtonSize size = WaslnyButtonSize.lg,
    IconData? icon,
    bool loading = false,
    bool expanded = true,
    WaslnyIconPosition iconPosition = WaslnyIconPosition.start,
  }) : this._(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: WaslnyButtonVariant.secondary,
         size: size,
         icon: icon,
         loading: loading,
         expanded: expanded,
         iconPosition: iconPosition,
       );

  /// Bordered outline button.
  const WaslnyButton.outline({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    WaslnyButtonSize size = WaslnyButtonSize.lg,
    IconData? icon,
    bool loading = false,
    bool expanded = true,
    WaslnyIconPosition iconPosition = WaslnyIconPosition.start,
  }) : this._(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: WaslnyButtonVariant.outline,
         size: size,
         icon: icon,
         loading: loading,
         expanded: expanded,
         iconPosition: iconPosition,
       );

  /// Ghost button â€” transparent with text only.
  const WaslnyButton.ghost({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    WaslnyButtonSize size = WaslnyButtonSize.lg,
    IconData? icon,
    bool loading = false,
    bool expanded = true,
    WaslnyIconPosition iconPosition = WaslnyIconPosition.start,
  }) : this._(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: WaslnyButtonVariant.ghost,
         size: size,
         icon: icon,
         loading: loading,
         expanded: expanded,
         iconPosition: iconPosition,
       );

  /// Danger button â€” red for destructive actions.
  const WaslnyButton.danger({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    WaslnyButtonSize size = WaslnyButtonSize.lg,
    IconData? icon,
    bool loading = false,
    bool expanded = true,
    WaslnyIconPosition iconPosition = WaslnyIconPosition.start,
  }) : this._(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: WaslnyButtonVariant.danger,
         size: size,
         icon: icon,
         loading: loading,
         expanded: expanded,
         iconPosition: iconPosition,
       );

  /// Plain text link style button.
  const WaslnyButton.text({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    WaslnyButtonSize size = WaslnyButtonSize.lg,
    IconData? icon,
    bool loading = false,
    bool expanded = true,
    WaslnyIconPosition iconPosition = WaslnyIconPosition.start,
  }) : this._(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: WaslnyButtonVariant.text,
         size: size,
         icon: icon,
         loading: loading,
         expanded: expanded,
         iconPosition: iconPosition,
       );

  // â”€â”€ Properties â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  final String label;
  final VoidCallback? onPressed;
  final WaslnyButtonVariant variant;
  final WaslnyButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final WaslnyIconPosition iconPosition;

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || loading;
    final colors = _colors(context);
    final dimensions = _dimensions();

    final content = _buildContent(colors, dimensions);

    final Widget button;

    switch (variant) {
      case WaslnyButtonVariant.primary:
        button = _buildElevated(colors, dimensions, content, isDisabled);
      case WaslnyButtonVariant.secondary:
        button = _buildElevated(colors, dimensions, content, isDisabled);
      case WaslnyButtonVariant.outline:
        button = _buildOutline(colors, dimensions, content, isDisabled);
      case WaslnyButtonVariant.ghost:
        button = _buildGhost(colors, dimensions, content, isDisabled);
      case WaslnyButtonVariant.danger:
        button = _buildElevated(colors, dimensions, content, isDisabled);
      case WaslnyButtonVariant.text:
        button = _buildText(colors, dimensions, content, isDisabled);
    }

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  // â”€â”€ Content builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildContent(_ButtonColors colors, _ButtonDimensions dims) {
    final textStyle = dims.textStyle?.copyWith(color: colors.foreground);

    if (loading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LoadingIndicator(color: colors.foreground, size: dims.loadingSize),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: textStyle),
        ],
      );
    }

    if (icon == null) {
      return Text(label, style: textStyle);
    }

    final iconWidget = Icon(
      icon,
      size: dims.iconSize,
      color: colors.foreground,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconPosition == WaslnyIconPosition.start) ...[
          iconWidget,
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(label, style: textStyle),
        if (iconPosition == WaslnyIconPosition.end) ...[
          const SizedBox(width: AppSpacing.sm),
          iconWidget,
        ],
      ],
    );
  }

  // â”€â”€ Style builders â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildElevated(
    _ButtonColors colors,
    _ButtonDimensions dims,
    Widget content,
    bool disabled,
  ) {
    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: dims.height,
        decoration: BoxDecoration(
          gradient: variant == WaslnyButtonVariant.primary
              ? (disabled ? null : AppColors.primaryGradient)
              : null,
          color: variant == WaslnyButtonVariant.primary
              ? (disabled ? colors.background : null)
              : colors.background,
          borderRadius: BorderRadius.circular(dims.radius),
          boxShadow: disabled || variant != WaslnyButtonVariant.primary
              ? null
              : AppColors.shadowPrimary,
        ),
        child: Center(child: content),
      ),
    );
  }

  Widget _buildOutline(
    _ButtonColors colors,
    _ButtonDimensions dims,
    Widget content,
    bool disabled,
  ) {
    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: dims.height,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(dims.radius),
          border: Border.all(
            color: disabled ? AppColors.border : colors.foreground!,
            width: 1.5,
          ),
        ),
        child: Center(child: content),
      ),
    );
  }

  Widget _buildGhost(
    _ButtonColors colors,
    _ButtonDimensions dims,
    Widget content,
    bool disabled,
  ) {
    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: Container(
        height: dims.height,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(dims.radius),
        ),
        child: Center(child: content),
      ),
    );
  }

  Widget _buildText(
    _ButtonColors colors,
    _ButtonDimensions dims,
    Widget content,
    bool disabled,
  ) {
    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: Container(
        height: dims.height,
        color: Colors.transparent,
        child: Center(child: content),
      ),
    );
  }

  // â”€â”€ Theme helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  _ButtonColors _colors(BuildContext context) {
    switch (variant) {
      case WaslnyButtonVariant.primary:
        return _ButtonColors(
          foreground: AppColors.textOnPrimary,
          background: AppColors.primary,
        );
      case WaslnyButtonVariant.secondary:
        return _ButtonColors(
          foreground: AppColors.textPrimary,
          background: AppColors.card,
        );
      case WaslnyButtonVariant.outline:
        return _ButtonColors(
          foreground: AppColors.primary,
          background: Colors.transparent,
        );
      case WaslnyButtonVariant.ghost:
        return _ButtonColors(
          foreground: AppColors.textSecondary,
          background: Colors.transparent,
        );
      case WaslnyButtonVariant.danger:
        return _ButtonColors(
          foreground: AppColors.textPrimary,
          background: AppColors.error,
        );
      case WaslnyButtonVariant.text:
        return _ButtonColors(
          foreground: AppColors.primary,
          background: Colors.transparent,
        );
    }
  }

  _ButtonDimensions _dimensions() {
    switch (size) {
      case WaslnyButtonSize.sm:
        return _ButtonDimensions(
          height: AppSpacing.buttonHeightSm,
          radius: AppSpacing.radiusMd,
          iconSize: AppSpacing.iconMd,
          loadingSize: 16,
          textStyle: AppTextStyles.buttonSmall,
        );
      case WaslnyButtonSize.md:
        return _ButtonDimensions(
          height: AppSpacing.buttonHeightMd,
          radius: AppSpacing.radiusLg,
          iconSize: AppSpacing.iconLg,
          loadingSize: 18,
          textStyle: AppTextStyles.buttonSmall,
        );
      case WaslnyButtonSize.lg:
        return _ButtonDimensions(
          height: AppSpacing.buttonHeightLg,
          radius: AppSpacing.radiusLg,
          iconSize: AppSpacing.iconLg,
          loadingSize: 20,
          textStyle: AppTextStyles.button,
        );
    }
  }
}

// â”€â”€â”€ Internal types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum WaslnyButtonVariant { primary, secondary, outline, ghost, danger, text }

enum WaslnyButtonSize { sm, md, lg }

enum WaslnyIconPosition { start, end }

class _ButtonColors {
  final Color? foreground;
  final Color? background;
  const _ButtonColors({this.foreground, this.background});
}

class _ButtonDimensions {
  final double height;
  final double radius;
  final double iconSize;
  final double loadingSize;
  final TextStyle? textStyle;
  const _ButtonDimensions({
    required this.height,
    required this.radius,
    required this.iconSize,
    required this.loadingSize,
    required this.textStyle,
  });
}

// â”€â”€â”€ Loading Indicator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _LoadingIndicator extends StatelessWidget {
  final Color? color;
  final double size;
  const _LoadingIndicator({this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
    );
  }
}
