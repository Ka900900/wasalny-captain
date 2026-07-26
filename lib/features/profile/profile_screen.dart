import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waslny_captain/widgets/image_source_picker.dart';

import 'package:waslny_captain/core/design_system/design_system.dart';
import 'package:waslny_captain/core/models/driver_profile.dart';
import 'package:waslny_captain/core/repositories/driver_repository.dart';
import 'package:waslny_captain/core/services/api_service.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/image_upload_service.dart';
import 'package:waslny_captain/features/auth/vehicle_info_screen.dart';
import 'package:waslny_captain/features/earnings/earnings_screen.dart';
import 'package:waslny_captain/features/profile/edit_profile_screen.dart';
import 'package:waslny_captain/features/ratings/ratings_screen.dart';
import 'package:waslny_captain/features/profile/settings_screen.dart';
import 'package:waslny_captain/features/support/support_chat_screen.dart';
import 'package:waslny_captain/features/wallet/wallet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;
  bool _isUploading = false;

  // ──────────────────────────────────────────────
  // Navigation
  // ──────────────────────────────────────────────

  Future<void> _navigateToEditProfile(DriverProfile? profile) async {
    try {
      HapticFeedback.lightImpact();
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
      );
      if (changed == true && mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: ${e.toString().replaceAll(RegExp(r'^Exception: '), '')}',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────
  // Pick & upload profile photo (via Railway backend)
  // ──────────────────────────────────────────────

  /// يختار الكابتن صورة جديدة ثم يرفعها إلى الـ Backend (محمي بـ JWT)
  /// ويحدّث حقل `photoUrl` في Firestore فورًا. يعرض مؤشر تحميل أثناء الرفع
  /// وينبّه عند الفشل دون إغلاق التطبيق.
  Future<void> _pickAndUploadPhoto(DriverProfile? profile) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !mounted) return;

    final picked = await pickImageWithSourceSheet(context);
    if (picked == null) return; // المستخدم ألغى الاختيار

    if (!mounted) return;
    setState(() => _isUploading = true);

    try {
      final imageUrl = await ImageUploadService.instance.uploadImage(
        type: UploadType.profile,
        file: File(picked.path),
      );

      if (!mounted) return;

      if (imageUrl == null) {
        // فشل الرفع (شبكة/401/500)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر رفع الصورة. تحقق من الاتصال وحاول مرة أخرى.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // تحديث حقول photoUrl + profilePic في Firestore (merge — دون مسح باقي الحقول)
      // نحتاج نحدّث `profilePic` عشان CaptainModel (اللي بيستخدمه Stream تاني)
      // يشوف الصورة الجديدة فورًا من غير ما يفضل عالق على الصورة القديمة من Google.
      await DriverRepository.instance.updateProfile(
        uid: uid,
        updates: {'photoUrl': imageUrl, 'profilePic': imageUrl},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الصورة الشخصية بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء رفع الصورة: ${e.toString().replaceAll(RegExp(r'^Exception: '), '')}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ──────────────────────────────────────────────
  // Logout
  // ──────────────────────────────────────────────

  Future<void> _confirmAndLogout() async {
    HapticFeedback.mediumImpact();

    final bool confirmed = await WaslnyDialog.confirm(
      context: context,
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      confirmLabel: 'تسجيل الخروج',
      cancelLabel: 'إلغاء',
      isDestructive: true,
    );

    if (confirmed != true) return;

    setState(() => _isLoggingOut = true);

    try {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الخروج: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────
  // Document compliance banner
  // ──────────────────────────────────────────────

  Widget _buildDocumentsBanner(DriverProfile profile) {
    final now = DateTime.now();
    final status = profile.compliance(now);
    if (status == DocumentCompliance.submitted) return const SizedBox.shrink();
    late final String text;
    late final Color color;
    if (status == DocumentCompliance.banned) {
      final until = profile.banUntil;
      text = until != null
          ? 'تم حظرك لعدم رفع المستندات المطلوبة (حتى ${_fmtProfileDate(until)})'
          : 'تم حظرك لعدم رفع المستندات المطلوبة';
      color = AppColors.error;
    } else {
      final daysLeft = profile.daysLeftInGrace(now);
      text = 'متبقٍ $daysLeft يوم لرفع المستندات قبل الحظر';
      color = AppColors.warning;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfileScreen(profile: profile),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.bodyMedium?.copyWith(color: color),
                ),
              ),
              Icon(Icons.chevron_left, color: color),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtProfileDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String uid = AuthService.instance.currentUser?.uid ?? '';

    // Guard against unauthenticated user
    if (uid.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_circle_rounded,
                    color: AppColors.textMuted,
                    size: 64,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'لم يتم تسجيل الدخول',
                    style: AppTextStyles.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'يرجى تسجيل الدخول لعرض الملف الشخصي',
                    style: AppTextStyles.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  WaslnyButton.primary(
                    label: 'تسجيل الدخول',
                    icon: Icons.login_rounded,
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (_) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: ApiService.instance.getProfile(),
            builder: (context, snapshot) {
              // Handle errors gracefully
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: AppColors.error,
                          size: 48,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'تعذر تحميل الملف الشخصي',
                          style: AppTextStyles.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'تحقق من اتصالك بالإنترنت',
                          style: AppTextStyles.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        WaslnyButton.outline(
                          label: 'إعادة المحاولة',
                          icon: Icons.refresh_rounded,
                          onPressed: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Parse captain data from backend API response into DriverProfile
              final captainData =
                  snapshot.data?['captain'] as Map<String, dynamic>?;
              final DriverProfile? profile = captainData != null
                  ? DriverProfile(
                      uid: captainData['firebaseUid'] as String? ?? uid,
                      name: captainData['name'] as String? ?? '',
                      phone: captainData['phone'] as String? ?? '',
                      photoUrl: captainData['photoUrl'] as String?,
                      carPhotoUrl: captainData['carPhotoUrl'] as String?,
                      nationalId: null,
                      idCardUrl: captainData['idCardUrl'] as String?,
                      idCardBackUrl: captainData['idCardBackUrl'] as String?,
                      vehicleType: captainData['vehicleType'] as String? ?? '',
                      vehicleModel:
                          captainData['vehicleModel'] as String? ?? '',
                      vehicleColor:
                          captainData['vehicleColor'] as String? ?? '',
                      vehicleNumber:
                          captainData['vehicleNumber'] as String? ?? '',
                      licenseUrl: captainData['licenseUrl'] as String?,
                      licenseBackUrl: captainData['licenseBackUrl'] as String?,
                      licenseNumber: captainData['licenseNumber'] as String?,
                      insuranceUrl: captainData['insuranceUrl'] as String?,
                      criminalRecordUrl:
                          captainData['criminalRecordUrl'] as String?,
                      drugTestUrl: captainData['drugTestUrl'] as String?,
                      documentsGraceEndsAt: null,
                      isBanned: false,
                      banUntil: null,
                      rating: (captainData['rating'] as num?)?.toDouble(),
                      createdAt: captainData['createdAt'] != null
                          ? DateTime.parse(captainData['createdAt'] as String)
                          : DateTime.now(),
                      updatedAt: captainData['updatedAt'] != null
                          ? DateTime.parse(captainData['updatedAt'] as String)
                          : DateTime.now(),
                    )
                  : null;
              final bool loading =
                  snapshot.connectionState == ConnectionState.waiting;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top bar ───────────────────────────────
                  _buildTopBar(),

                  // ── Header card ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      0,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                    ),
                    child: _buildHeaderCard(profile, loading),
                  ),

                  // ── Divider ───────────────────────────────
                  const Divider(height: 1),

                  // ── Menu list (backend API is the single source of truth)
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                        vertical: AppSpacing.lg,
                      ),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (profile != null) _buildDocumentsBanner(profile),
                        _ProfileMenuItem(
                          icon: Icons.person_outline_rounded,
                          iconColor: AppColors.primary,
                          title: 'الحساب الشخصي',
                          subtitle: 'تعديل الاسم والصورة',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditProfileScreen(profile: profile),
                              ),
                            ).then((changed) {
                              if (changed == true && mounted) {
                                setState(() {});
                              }
                            });
                          },
                        ),
                        _ProfileMenuItem(
                          icon: Icons.directions_car_outlined,
                          iconColor: AppColors.info,
                          title: 'معلومات المركبة',
                          subtitle: 'نوع السيارة، اللوحة',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const VehicleInfoScreen(),
                              ),
                            );
                          },
                        ),
                        _ProfileMenuItem(
                          icon: Icons.trending_up_rounded,
                          iconColor: AppColors.success,
                          title: 'الأرباح',
                          subtitle:
                              'المعدلات والأرباح اليومي والأسبوعي والشهري',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EarningsScreen(),
                              ),
                            );
                          },
                        ),
                        _ProfileMenuItem(
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: AppColors.warning,
                          title: 'المحفظة',
                          subtitle: 'الرصيد والمعاملات وشحن المحفظة',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WalletScreen(),
                              ),
                            );
                          },
                        ),
                        _ProfileMenuItem(
                          icon: Icons.star_outline_rounded,
                          iconColor: AppColors.warning,
                          title: 'التقييمات',
                          subtitle: 'آراء الركاب ونظام التقييم',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RatingsScreen(),
                              ),
                            );
                          },
                        ),
                        _ProfileMenuItem(
                          icon: Icons.help_outline_rounded,
                          iconColor: AppColors.info,
                          title: 'الدعم والمساعدة',
                          subtitle: 'الدردشة الحية مع الدعم',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SupportChatScreen(),
                              ),
                            );
                          },
                        ),
                        _ProfileMenuItem(
                          icon: Icons.settings_outlined,
                          iconColor: AppColors.textMuted,
                          title: 'الإعدادات',
                          subtitle: 'اللغة، الإشعارات',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),

                  // ── Logout button ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      0,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                    ),
                    child: WaslnyButton.danger(
                      label: 'تسجيل الخروج',
                      icon: Icons.logout_rounded,
                      loading: _isLoggingOut,
                      onPressed: _isLoggingOut ? null : _confirmAndLogout,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('حسابي', style: AppTextStyles.titleLarge),
        ],
      ),
    );
  }

  // ── Header card ─────────────────────────────────────────────

  Widget _buildHeaderCard(DriverProfile? profile, bool loading) {
    if (loading) return _buildHeaderShimmer();

    if (profile == null) return _buildHeaderShimmer();

    final String name = profile.name.isNotEmpty ? profile.name : '';
    final String phone = profile.phone.isNotEmpty
        ? profile.phone
        : AuthService.instance.currentPhoneNumber;
    final String? photoUrl = profile.photoUrl;
    final double rating = profile.rating ?? 0.0;

    return GestureDetector(
      onTap: () => _navigateToEditProfile(profile),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          boxShadow: AppColors.shadowMd,
        ),
        child: Row(
          children: [
            // Avatar with edit badge (tap to change photo)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _pickAndUploadPhoto(profile),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.cardElevated,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl) as ImageProvider
                        : const AssetImage('assets/myimage.jpg'),
                  ),
                  // مؤشر التحميل أثناء رفع الصورة
                  if (_isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.textOnPrimary,
                        size: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),

            // Name, phone, rating
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : phone,
                    style: AppTextStyles.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (name.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(phone, style: AppTextStyles.bodySmall),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : '—',
                        style: AppTextStyles.labelMedium?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('تعديل الملف', style: AppTextStyles.labelSmall),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── Shimmer skeleton ─────────────────────────────────────────

  Widget _buildHeaderShimmer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _ProfileMenuItem — menu row using design system tokens
// ═══════════════════════════════════════════════════════════════

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(icon, color: iconColor, size: AppSpacing.iconMd),
                ),
                const SizedBox(width: AppSpacing.lg),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(subtitle, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),

                // Trailing arrow
                const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
