/// Waslny Captain Design System
///
/// A complete set of reusable Flutter widgets and design tokens for
/// building consistent UI across the Waslny ecosystem.
///
/// ## Design Tokens (in `lib/core/theme/app_theme.dart`)
/// - [AppColors] — Color palette, gradients, shadows
/// - [AppSpacing] — Spacing, radius, icon, and button size constants
/// - [AppTextStyles] — Typography scale (Cairo font)
/// - [AppTheme] — Full ThemeData for Material theming
///
/// ## Components
/// - [WaslnyButton] — Multi-variant action button (primary, secondary, outline, ghost, danger, text)
/// - [WaslnyCard] — Base card container
/// - [WaslnyStatCard] — Dashboard stat card
/// - [WaslnyActionCard] — Tappable card with trailing arrow
/// - [WaslnyInfoCard] — Alert/info card with semantic colors
/// - [WaslnyBottomSheet] — Modal bottom sheet utilities
/// - [WaslnyDialog] — Dialog utilities (alert, confirm, input)
/// - [WaslnyTextField] — Enhanced text input
/// - [WaslnyPhoneField] — Phone number input
/// - [WaslnyDropdownField] — Dropdown form field
/// - [WaslnySearchField] — Search bar with clear
/// - [WaslnyStatusBadge] — Colored status chip
/// - [WaslnyStatusDot] — Animated pulsing status dot
/// - [WaslnyConnectionBanner] — Online/offline banner
library;

export 'package:waslny_captain/core/theme/app_theme.dart'
    show AppColors, AppSpacing, AppTextStyles, AppTheme;

export 'waslny_button.dart' show WaslnyButton;
export 'waslny_card.dart'
    show
        WaslnyCard,
        WaslnyStatCard,
        WaslnyActionCard,
        WaslnyInfoCard,
        WaslnyInfoCardType;
export 'waslny_bottom_sheet.dart' show WaslnyBottomSheet;
export 'waslny_dialog.dart' show WaslnyDialog;
export 'waslny_input_field.dart'
    show
        WaslnyTextField,
        WaslnyPhoneField,
        WaslnyDropdownField,
        WaslnySearchField;
export 'waslny_status_indicator.dart'
    show
        WaslnyStatusBadge,
        WaslnyStatusDot,
        WaslnyConnectionBanner,
        WaslnyStatusType;
