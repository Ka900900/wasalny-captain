import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _themeMode = SettingsService.instance.themeMode;
    _notificationsEnabled = SettingsService.instance.notificationsEnabled;
  }

  Future<void> _updateThemeMode(ThemeMode mode) async {
    await SettingsService.instance.updateThemeMode(mode);
    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> _updateNotifications(bool enabled) async {
    await SettingsService.instance.updateNotificationsEnabled(enabled);
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  Widget _buildThemeOption(ThemeMode mode, String title, String subtitle) {
    return RadioListTile<ThemeMode>(
      value: mode,
      title: Text(title, style: AppTextStyles.bodyLarge),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Text(
                'الثيم',
                style: AppTextStyles.headlineMedium?.copyWith(
                  color: theme.textTheme.headlineMedium?.color,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<ThemeMode>(
              groupValue: _themeMode,
              onChanged: (value) {
                if (value != null) _updateThemeMode(value);
              },
              child: Column(
                children: [
                  _buildThemeOption(
                    ThemeMode.system,
                    'الوضع التلقائي',
                    'يتبع إعدادات النظام',
                  ),
                  const Divider(height: 1),
                  _buildThemeOption(
                    ThemeMode.light,
                    'الوضع الفاتح',
                    'ألوان فاتحة ومريحة للنهار',
                  ),
                  const Divider(height: 1),
                  _buildThemeOption(
                    ThemeMode.dark,
                    'الوضع الداكن',
                    'ألوان داكنة لرؤية أريح',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.sm,
              ),
              child: Text('الإشعارات', style: AppTextStyles.headlineMedium),
            ),
            SwitchListTile(
              value: _notificationsEnabled,
              onChanged: _updateNotifications,
              title: Text(
                'تشغيل الإشعارات',
                style: AppTextStyles.bodyLarge?.copyWith(
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              subtitle: Text(
                'استلام تنبيهات الركوب والمحفظة والدعم',
                style: AppTextStyles.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
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
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Text(
                'هذه الإعدادات تحفظ محلياً على الجهاز ويمكن تعديلها في أي وقت.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
