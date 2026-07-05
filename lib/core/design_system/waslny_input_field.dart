import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';

/// ───────────────────────────────────────────────────────────────
/// Waslny Input Fields — Reusable form field widgets.
/// ───────────────────────────────────────────────────────────────
///
/// - [WaslnyTextField] — Standard text input with label, validation, icons
/// - [WaslnyPhoneField] — Phone number input with country code prefix
/// - [WaslnyDropdownField] — Form-based dropdown with label
/// - [WaslnySearchField] — Search bar with debounce and clear

// ═══════════════════════════════════════════════════════════════
// TEXT FIELD
// ═══════════════════════════════════════════════════════════════

/// A enhanced text input field with consistent Waslny styling.
///
/// Supports labels, validation, prefix/suffix icons, and more.
class WaslnyTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final void Function()? onTap;
  final AutovalidateMode autovalidateMode;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final EdgeInsets? contentPadding;
  final Color? fillColor;

  const WaslnyTextField({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.prefix,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.contentPadding,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(label!, style: AppTextStyles.labelLarge),
          ),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTap: onTap,
          autovalidateMode: autovalidateMode,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          style: AppTextStyles.bodyLarge?.copyWith(
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            prefix: prefix,
            suffix: suffix,
            fillColor: fillColor,
            counterText: maxLength != null ? null : '',
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PHONE FIELD
// ═══════════════════════════════════════════════════════════════

/// A phone number input field with a country code prefix.
class WaslnyPhoneField extends StatelessWidget {
  final TextEditingController? controller;
  final String countryCode;
  final String? hintText;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  const WaslnyPhoneField({
    super.key,
    this.controller,
    this.countryCode = '+20',
    this.hintText = 'XXX XXX XXXX',
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      maxLength: 10,
      validator: validator,
      onChanged: onChanged,
      style: AppTextStyles.bodyLarge,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '',
        prefix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              countryCode,
              style: AppTextStyles.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              color: AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DROPDOWN FIELD
// ═══════════════════════════════════════════════════════════════

/// A form-based dropdown with label and consistent styling.
class WaslnyDropdownField<T> extends StatelessWidget {
  final String? label;
  final String? hintText;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final Widget? prefixIcon;
  final Color? fillColor;

  const WaslnyDropdownField({
    super.key,
    this.label,
    this.hintText,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(label!, style: AppTextStyles.labelLarge),
          ),
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textMuted,
            size: AppSpacing.iconLg,
          ),
          style: AppTextStyles.bodyLarge,
          dropdownColor: AppColors.surfaceElevated,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            fillColor: fillColor,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SEARCH FIELD
// ═══════════════════════════════════════════════════════════════

/// A search bar with a debounced callback and clear button.
class WaslnySearchField extends StatefulWidget {
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final Color? fillColor;

  const WaslnySearchField({
    super.key,
    this.hintText = 'بحث...',
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.controller,
    this.onTap,
    this.fillColor,
  });

  @override
  State<WaslnySearchField> createState() => _WaslnySearchFieldState();
}

class _WaslnySearchFieldState extends State<WaslnySearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      style: AppTextStyles.bodyLarge,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
          size: AppSpacing.iconLg,
        ),
        suffixIcon: _controller.text.isNotEmpty
            ? GestureDetector(
                onTap: _clear,
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: AppSpacing.iconLg,
                ),
              )
            : null,
        fillColor: widget.fillColor,
      ),
    );
  }
}
