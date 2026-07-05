import 'package:flutter/material.dart';
import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/core/design_system/waslny_button.dart';

/// ───────────────────────────────────────────────────────────────
/// Waslny Dialog — Reusable dialog utilities.
/// ───────────────────────────────────────────────────────────────
///
/// Provides:
/// - [WaslnyDialog.show] — Fully custom dialog
/// - [WaslnyDialog.alert] — Simple alert with single action
/// - [WaslnyDialog.confirm] — Confirmation with cancel/confirm
/// - [WaslnyDialog.input] — Dialog with a text field
///
/// Usage:
/// ```dart
/// final confirmed = await WaslnyDialog.confirm(
///   context,
///   title: 'تأكيد الحذف',
///   message: 'هل أنت متأكد؟',
/// );
/// ```
class WaslnyDialog {
  WaslnyDialog._();

  // ── Custom ─────────────────────────────────────────

  /// Shows a fully custom dialog.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    Widget? content,
    List<Widget>? actions,
    bool isDismissible = true,
    Color? backgroundColor,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierColor: AppColors.scrim,
      builder: (ctx) => PopScope(
        canPop: isDismissible,
        child: AlertDialog(
          backgroundColor: backgroundColor ?? AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          titlePadding: EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
            title != null && message == null && content == null
                ? AppSpacing.lg
                : 0,
          ),
          contentPadding: EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            actions != null ? 0 : AppSpacing.xxl,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          title: title != null
              ? Text(title, style: AppTextStyles.headlineMedium)
              : null,
          content:
              content ??
              (message != null
                  ? Text(message, style: AppTextStyles.bodyLarge)
                  : null),
          actions: actions,
          buttonPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ── Alert ──────────────────────────────────────────

  /// Shows a simple alert dialog with a single action button.
  static Future<bool> alert({
    required BuildContext context,
    required String title,
    required String message,
    String actionLabel = 'حسناً',
  }) {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      actions: [
        WaslnyButton.primary(
          label: actionLabel,
          onPressed: () => Navigator.of(context).pop(true),
          expanded: true,
        ),
      ],
    ).then((r) => r ?? false);
  }

  // ── Confirm ────────────────────────────────────────

  /// Shows a confirmation dialog with cancel/confirm actions.
  ///
  /// Returns `true` if confirmed, `false` if cancelled.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String cancelLabel = 'إلغاء',
    String confirmLabel = 'تأكيد',
    Color? confirmColor,
    bool isDestructive = false,
  }) {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      actions: [
        Row(
          children: [
            Expanded(
              child: WaslnyButton.outline(
                label: cancelLabel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: isDestructive
                  ? WaslnyButton.danger(
                      label: confirmLabel,
                      onPressed: () => Navigator.of(context).pop(true),
                    )
                  : WaslnyButton.primary(
                      label: confirmLabel,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
            ),
          ],
        ),
      ],
    ).then((r) => r ?? false);
  }

  // ── Input ──────────────────────────────────────────

  /// Shows a dialog with a text field.
  ///
  /// Returns the entered text, or `null` if dismissed.
  static Future<String?> input({
    required BuildContext context,
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String? confirmLabel,
    String? cancelLabel,
    TextInputType keyboardType = TextInputType.text,
    FormFieldValidator<String>? validator,
    int? maxLength,
    bool obscureText = false,
    Widget? prefixIcon,
  }) {
    final controller = TextEditingController(text: initialValue);
    final focusNode = FocusNode();
    final formKey = GlobalKey<FormState>();

    return show<String>(
      context: context,
      title: title,
      message: message,
      content: Form(
        key: formKey,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            validator: validator,
            maxLength: maxLength,
            obscureText: obscureText,
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon as IconData?, size: AppSpacing.iconMd)
                  : null,
              counterText: '',
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: WaslnyButton.outline(
                label: cancelLabel ?? 'إلغاء',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: WaslnyButton.primary(
                label: confirmLabel ?? 'موافق',
                onPressed: () {
                  if (formKey.currentState?.validate() ?? true) {
                    Navigator.of(context).pop(controller.text);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    ).then((r) {
      controller.dispose();
      focusNode.dispose();
      return r;
    });
  }

  // ── Bottom Sheet Style (alternative to dialogs) ────

  /// Shows a bottom-sheet style confirmation.
  ///
  /// This is often more natural on mobile than a center dialog.
  static Future<bool> bottomSheetConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String cancelLabel = 'إلغاء',
    String confirmLabel = 'تأكيد',
    bool isDestructive = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppSpacing.radiusXxl),
            topRight: Radius.circular(AppSpacing.radiusXxl),
          ),
        ),
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          top: AppSpacing.xxl,
          bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
            Text(title, style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: WaslnyButton.outline(
                    label: cancelLabel,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: isDestructive
                      ? WaslnyButton.danger(
                          label: confirmLabel,
                          onPressed: () => Navigator.of(context).pop(true),
                        )
                      : WaslnyButton.primary(
                          label: confirmLabel,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).then((r) => r ?? false);
  }
}
