import 'dart:async';
import 'package:flutter/material.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/repositories/notification_repository.dart';
import 'package:waslny_captain/core/models/notification_models.dart';

/// Screen that displays all push notifications for the captain.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repo = NotificationRepository.instance;

  List<AppNotification> _notifications = [];
  bool _loading = true;
  StreamSubscription<List<AppNotification>>? _sub;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    // Stream notifications in real time
    _sub = _repo.streamNotifications(uid).listen((list) {
      if (mounted) {
        setState(() {
          _notifications = list;
          _loading = false;
        });
      }
    });
  }

  /// Mark a single notification as read.
  Future<void> _markAsRead(AppNotification notif) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await _repo.markAsRead(uid, notif.id);
  }

  /// Mark all as read.
  Future<void> _markAllAsRead() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await _repo.markAllAsRead(uid);
  }

  // ────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBg,
        title: const Text('الإشعارات'),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'تحديد الكل كمقروء',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 80, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'لا توجد إشعارات',
              style: AppTextStyles.headlineSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سوف تظهر هنا إشعارات الرحلات والمحفظة والعروض',
              style: AppTextStyles.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null) {
          final list = await _repo.fetchNotifications(uid);
          if (mounted) {
            setState(() {
              _notifications = list;
            });
          }
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          return _NotificationTile(
            notification: notif,
            onTap: () {
              _markAsRead(notif);
            },
          );
        },
      ),
    );
  }
}

/// A single notification tile widget.
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: unread ? AppColors.card : AppColors.primaryBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: unread ? AppColors.primary.withValues(alpha: 0.2) : AppColors.border,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _iconColor().withValues(alpha: 0.15),
          child: Icon(_iconData, color: _iconColor(), size: 20),
        ),
        title: Text(
          notification.title,
          style: AppTextStyles.bodyMedium?.copyWith(
            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          notification.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall?.copyWith(
            color: unread ? AppColors.textSecondary : AppColors.textMuted,
          ),
        ),
        trailing: unread
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.shadowSm,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  IconData get _iconData {
    switch (notification.type) {
      case NotificationType.newRide:
        return Icons.route;
      case NotificationType.tripUpdate:
        return Icons.directions_car;
      case NotificationType.walletUpdate:
        return Icons.account_balance_wallet;
      case NotificationType.promotion:
        return Icons.local_offer;
    }
  }

  Color _iconColor() {
    switch (notification.type) {
      case NotificationType.newRide:
        return AppColors.info;
      case NotificationType.tripUpdate:
        return AppColors.warning;
      case NotificationType.walletUpdate:
        return AppColors.primary;
      case NotificationType.promotion:
        return AppColors.info;
    }
  }
}