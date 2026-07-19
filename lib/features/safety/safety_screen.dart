import 'dart:async';
import 'package:flutter/material.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/core/services/auth_service.dart';
import 'package:waslny_captain/core/services/safety_service.dart';
import 'package:waslny_captain/core/repositories/safety_repository.dart';
import 'package:waslny_captain/core/models/safety_models.dart';

/// Safety screen with SOS button, emergency contacts, and live location
/// sharing.
class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen>
    with TickerProviderStateMixin {
  final SafetyService _safetyService = SafetyService.instance;
  final SafetyRepository _repo = SafetyRepository.instance;

  // ── SOS ────────────────────────────────────────────
  bool _sosActive = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Emergency Contacts ─────────────────────────────
  List<EmergencyContact> _contacts = [];
  bool _loadingContacts = true;

  // ── Live Sharing ───────────────────────────────────
  bool _isSharing = false;
  bool _sharingLoading = false;

  // ── SOS History ────────────────────────────────────
  List<SOSAlert> _sosHistory = [];
  bool _loadingHistory = true;

  StreamSubscription<List<EmergencyContact>>? _contactsSub;

  // ────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _contactsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    // Stream contacts
    _contactsSub = _repo.streamEmergencyContacts(uid).listen((list) {
      if (mounted) {
        setState(() {
          _contacts = list;
          _loadingContacts = false;
        });
      }
    });

    // Fetch SOS history
    _sosHistory = await _repo.fetchSOSHistory(uid);
    if (mounted) {
      setState(() => _loadingHistory = false);
    }

    // Check sharing state
    final state = await _repo.fetchSharingState(uid);
    if (mounted) {
      setState(() => _isSharing = state?.isSharing ?? false);
    }

    // Listen for sharing changes from SafetyService
    _safetyService.onSharingChanged = (sharing) {
      if (mounted) {
        setState(() => _isSharing = sharing);
      }
    };
  }

  // ────────────────────────────────────────────────────
  // SOS Actions
  // ────────────────────────────────────────────────────

  Future<void> _triggerSOS() async {
    // Vibrate / haptic feedback would be nice here
    setState(() => _sosActive = true);

    try {
      await _safetyService.triggerSOS();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🆘 تم إرسال إشارة استغاثة!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sosActive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال إشارة الاستغاثة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resolveSOS() async {
    await _safetyService.resolveSOS();
    if (mounted) {
      setState(() => _sosActive = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حل إشارة الاستغاثة'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────
  // Live Sharing
  // ────────────────────────────────────────────────────

  Future<void> _toggleSharing() async {
    setState(() => _sharingLoading = true);

    if (_isSharing) {
      await _safetyService.stopLiveSharing();
    } else {
      await _safetyService.startLiveSharing();
    }

    if (mounted) {
      setState(() {
        _isSharing = _safetyService.isSharing;
        _sharingLoading = false;
      });
    }
  }

  // ────────────────────────────────────────────────────
  // Contacts
  // ────────────────────────────────────────────────────

  Future<void> _addContact() async {
    final contact = await _showContactDialog();
    if (contact == null) return;

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await _repo.addEmergencyContact(uid, contact);
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف جهة اتصال'),
        content: Text('هل تريد حذف "${contact.name}" من جهات الاتصال؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.deleteEmergencyContact(uid, contact.id);
    }
  }

  Future<EmergencyContact?> _showContactDialog({
    EmergencyContact? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final relCtrl = TextEditingController(text: existing?.relationship ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(existing != null ? 'تعديل جهة اتصال' : 'إضافة جهة اتصال'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'أدخل رقم الهاتف'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: relCtrl,
                  decoration: const InputDecoration(
                    labelText: 'صلة القرابة (أب، أخ، زوجة، ...)',
                    prefixIcon: Icon(Icons.people),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, {
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'relationship': relCtrl.text.trim(),
                  });
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return null;

    return EmergencyContact(
      id: existing?.id ?? '',
      name: result['name'] ?? '',
      phone: result['phone'] ?? '',
      relationship: result['relationship'] ?? '',
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
  }

  // ────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأمان والسلامة'),
        actions: [
          if (_sosActive)
            TextButton.icon(
              onPressed: _resolveSOS,
              icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
              label: const Text(
                'تم الحل',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSOSButton(theme),
            const SizedBox(height: 24),
            _buildLiveSharingCard(theme),
            const SizedBox(height: 24),
            _buildEmergencyContactsSection(theme),
            const SizedBox(height: 24),
            _buildSOSHistorySection(theme),
          ],
        ),
      ),
    );
  }

  // ── SOS Button ────────────────────────────────────────

  Widget _buildSOSButton(ThemeData theme) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _sosActive ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: _sosActive ? scale : 1.0,
          child: GestureDetector(
            onTap: _sosActive ? null : _triggerSOS,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sosActive ? Colors.red : Colors.red.shade700,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: _sosActive ? 0.5 : 0.3),
                    blurRadius: _sosActive ? 30 : 15,
                    spreadRadius: _sosActive ? 8 : 2,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sosActive ? Icons.sos : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sosActive ? '🆘 نشط' : 'SOS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Live Sharing Card ──────────────────────────────────

  Widget _buildLiveSharingCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSharing
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isSharing
                  ? Colors.greenAccent.withValues(alpha: 0.15)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on,
              color: _isSharing ? Colors.greenAccent : AppColors.textMuted,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مشاركة الموقع المباشر',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSharing
                      ? 'موقعك مرئي الآن لجهات الاتصال'
                      : 'شارك موقعك لحظة بلحظة مع جهات الاتصال',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _sharingLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: _isSharing,
                  onChanged: (_) => _toggleSharing(),
                  activeTrackColor: Colors.greenAccent,
                ),
        ],
      ),
    );
  }

  // ── Emergency Contacts Section ────────────────────────

  Widget _buildEmergencyContactsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.contacts,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'جهات الاتصال في الطوارئ',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addContact,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingContacts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_contacts.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.person_add_alt_1,
                    size: 40,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'لا توجد جهات اتصال',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'أضف جهات اتصال ليتم إشعارهم في حالات الطوارئ',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(_contacts.length, (i) {
            final contact = _contacts[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                    child: Text(
                      contact.name.isNotEmpty
                          ? contact.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          contact.phone,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (contact.relationship.isNotEmpty)
                          Text(
                            contact.relationship,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () => _deleteContact(contact),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── SOS History Section ──────────────────────────────

  Widget _buildSOSHistorySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              'سجل إشارات الاستغاثة',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_sosHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'لا يوجد سابق استغاثة',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          ...List.generate(_sosHistory.length, (i) {
            final alert = _sosHistory[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _statusIcon(alert.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.status.displayName,
                          style: TextStyle(
                            color: _statusColor(alert.status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatDate(alert.createdAt),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (alert.latitude != null && alert.longitude != null)
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────

  Widget _statusIcon(SOSStatus status) {
    switch (status) {
      case SOSStatus.active:
        return const Icon(Icons.warning, color: Colors.red, size: 20);
      case SOSStatus.resolved:
        return const Icon(
          Icons.check_circle,
          color: Colors.greenAccent,
          size: 20,
        );
      case SOSStatus.cancelled:
        return const Icon(Icons.cancel, color: AppColors.textMuted, size: 20);
    }
  }

  Color _statusColor(SOSStatus status) {
    switch (status) {
      case SOSStatus.active:
        return Colors.red;
      case SOSStatus.resolved:
        return Colors.greenAccent;
      case SOSStatus.cancelled:
        return AppColors.textMuted;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
