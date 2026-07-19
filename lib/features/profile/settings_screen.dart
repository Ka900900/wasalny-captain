import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:waslny_captain/core/design_system/design_system.dart';
import 'package:waslny_captain/core/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _themeMode;
  late bool _notificationsEnabled;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _themeMode = SettingsService.instance.themeMode;
    _notificationsEnabled = SettingsService.instance.notificationsEnabled;
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = 'v${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = 'v1.0.0');
    }
  }

  Future<void> _updateThemeMode(ThemeMode mode) async {
    await SettingsService.instance.updateThemeMode(mode);
    setState(() => _themeMode = mode);
  }

  Future<void> _updateNotifications(bool enabled) async {
    await SettingsService.instance.updateNotificationsEnabled(enabled);
    setState(() => _notificationsEnabled = enabled);
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '\u0647\u0630\u0647 \u0627\u0644\u0645\u064a\u0632\u0629 \u0633\u062a\u0643\u0648\u0646 \u0645\u062a\u0627\u062d\u0629 \u0642\u0631\u064a\u0628\u0627\u064b',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Text(title, style: AppTextStyles.headlineMedium),
    );
  }

  Widget _buildThemeTile({
    required ThemeMode value,
    required String title,
    required String subtitle,
  }) {
    final selected = value == _themeMode;
    return ListTile(
      leading: Radio<ThemeMode>(
        value: value,
        groupValue: _themeMode,
        onChanged: (v) {
          if (v != null) _updateThemeMode(v);
        },
        activeColor: AppColors.primary,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge?.copyWith(
          color: selected ? AppColors.primary : null,
        ),
      ),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      onTap: () => _updateThemeMode(value),
    );
  }

  Widget _disabledTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(icon, color: AppColors.textMuted, size: AppSpacing.iconMd),
      ),
      title: Text(
        title,
        style: AppTextStyles.titleSmall?.copyWith(color: AppColors.textMuted),
      ),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: const Icon(Icons.chevron_left, color: AppColors.textMuted),
      onTap: _showComingSoon,
    );
  }

  Widget _clickableTile({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(icon, color: color, size: AppSpacing.iconMd),
      ),
      title: Text(title, style: AppTextStyles.titleSmall),
      trailing: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  // ── Build ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a',
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            // ── 1. Theme ────────────────────────────────
            _sectionHeader('\u0627\u0644\u062b\u064a\u0645'),
            const SizedBox(height: AppSpacing.sm),
            _buildThemeTile(
              value: ThemeMode.system,
              title:
                  '\u0627\u0644\u0648\u0636\u0639 \u0627\u0644\u062a\u0644\u0642\u0627\u0626\u064a',
              subtitle:
                  '\u064a\u062a\u0628\u0639 \u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u0646\u0638\u0627\u0645',
            ),
            const Divider(height: 1),
            _buildThemeTile(
              value: ThemeMode.dark,
              title:
                  '\u0627\u0644\u0648\u0636\u0639 \u0627\u0644\u062f\u0627\u0643\u0646',
              subtitle:
                  '\u0623\u0644\u0648\u0627\u0646 \u062f\u0627\u0643\u0646\u0629 \u0644\u0631\u0624\u064a\u0629 \u0623\u0631\u064a\u062d',
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 2. Notifications ────────────────────────
            _sectionHeader(
              '\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a',
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              value: _notificationsEnabled,
              onChanged: _updateNotifications,
              title: Text(
                '\u062a\u0634\u063a\u064a\u0644 \u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a',
                style: AppTextStyles.bodyLarge,
              ),
              subtitle: Text(
                '\u0627\u0633\u062a\u0644\u0627\u0645 \u062a\u0646\u0628\u064a\u0647\u0627\u062a \u0627\u0644\u0631\u0643\u0648\u0628 \u0648\u0627\u0644\u0645\u062d\u0641\u0638\u0629 \u0648\u0627\u0644\u062f\u0639\u0645',
                style: AppTextStyles.bodySmall,
              ),
              tileColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.sm,
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 3. Navigation App (UI only) ─────────────
            _sectionHeader(
              '\u062e\u0631\u0627\u0626\u0637 \u0627\u0644\u062a\u0646\u0642\u0644',
            ),
            const SizedBox(height: AppSpacing.sm),
            _disabledTile(
              icon: Icons.map_outlined,
              title:
                  '\u062a\u0637\u0628\u064a\u0642 \u0627\u0644\u0645\u0644\u0627\u062d\u0629 \u0627\u0644\u0627\u0641\u062a\u0631\u0627\u0636\u064a',
              subtitle: 'Google Maps',
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 4. Distance Unit (UI only) ──────────────
            _sectionHeader(
              '\u0648\u062d\u062f\u0629 \u0627\u0644\u0645\u0633\u0627\u0641\u0627\u062a',
            ),
            const SizedBox(height: AppSpacing.sm),
            _disabledTile(
              icon: Icons.straighten_outlined,
              title: '\u0627\u0644\u0643\u064a\u0644\u0648\u0645\u062a\u0631',
              subtitle: '\u0643\u064a\u0644\u0648\u0645\u062a\u0631 (km)',
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 5. Language (UI only) ───────────────────
            _sectionHeader('\u0627\u0644\u0644\u063a\u0629'),
            const SizedBox(height: AppSpacing.sm),
            _disabledTile(
              icon: Icons.language_outlined,
              title: '\u0627\u0644\u0639\u0631\u0628\u064a\u0629',
              subtitle: 'Arabic',
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 6. Legal Documents (UI only) ────────────
            _sectionHeader(
              '\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a\u0629',
            ),
            const SizedBox(height: AppSpacing.sm),
            _clickableTile(
              icon: Icons.description_outlined,
              color: AppColors.textSecondary,
              title:
                  '\u0633\u064a\u0627\u0633\u0629 \u0627\u0644\u062e\u0635\u0648\u0635\u064a\u0629',
              onTap: _showComingSoon,
            ),
            const Divider(height: 1),
            _clickableTile(
              icon: Icons.article_outlined,
              color: AppColors.textSecondary,
              title:
                  '\u0634\u0631\u0648\u0637 \u0627\u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645',
              onTap: _showComingSoon,
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── 7. App Version ──────────────────────────
            _sectionHeader(
              '\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0627\u0644\u062a\u0637\u0628\u064a\u0642',
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                  size: AppSpacing.iconMd,
                ),
              ),
              title: Text(
                '\u0625\u0635\u062f\u0627\u0631 \u0627\u0644\u062a\u0637\u0628\u064a\u0642',
                style: AppTextStyles.titleSmall,
              ),
              subtitle: Text(
                _appVersion.isEmpty
                    ? '\u062c\u0627\u0631\u064a \u0627\u0644\u062a\u062d\u0645\u064a\u0644...'
                    : _appVersion,
                style: AppTextStyles.bodySmall,
              ),
              tileColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.xs,
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
