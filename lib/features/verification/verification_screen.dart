import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/core/services/document_upload_service.dart';
import 'package:waslny_captain/features/verification/camera_screen.dart';

/// A single step in the verification flow.
class VerificationStep {
  final String title;
  final String subtitle;
  final UploadDocType docType;
  final CaptureMode captureMode;
  final IconData icon;

  const VerificationStep({
    required this.title,
    required this.subtitle,
    required this.docType,
    required this.captureMode,
    required this.icon,
  });
}

/// Result returned when the entire verification flow is complete.
class VerificationResult {
  final Map<UploadDocType, String> uploadedUrls;

  const VerificationResult({required this.uploadedUrls});
}

/// Full‑screen verification flow that guides the captain through:
/// 1. National ID — Front
/// 2. National ID — Back
/// 3. Driver License
/// 4. Face / Selfie (with ML Kit validation)
///
/// Each step:
/// - Opens the custom camera with the right overlay mask
/// - Shows upload progress after capture
/// - Handles retry on failure
/// - Displays a green checkmark on success
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  /// The list of steps the user must complete.
  static const List<VerificationStep> steps = [
    VerificationStep(
      title: 'البطاقة الشخصية — الوجه الأمامي',
      subtitle: 'صوّر وجه البطاقة الشخصية',
      docType: UploadDocType.idFront,
      captureMode: CaptureMode.document,
      icon: Icons.badge_outlined,
    ),
    VerificationStep(
      title: 'البطاقة الشخصية — الوجه الخلفي',
      subtitle: 'صوّر ظهر البطاقة الشخصية',
      docType: UploadDocType.idBack,
      captureMode: CaptureMode.document,
      icon: Icons.badge_outlined,
    ),
    VerificationStep(
      title: 'رخصة القيادة',
      subtitle: 'صوّر رخصة القيادة',
      docType: UploadDocType.license,
      captureMode: CaptureMode.document,
      icon: Icons.drive_eta_outlined,
    ),
    VerificationStep(
      title: 'صورة شخصية (Selfie)',
      subtitle: 'التقط صورة وجهك للتحقق من الهوية',
      docType: UploadDocType.face,
      captureMode: CaptureMode.face,
      icon: Icons.face_outlined,
    ),
  ];

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  int _currentStep = 0;
  final Map<UploadDocType, String> _uploadedUrls = {};
  final Set<UploadDocType> _uploading = {};
  final Set<UploadDocType> _failed = {};
  StreamSubscription<UploadResult>? _uploadSubscription;

  bool get _allDone => _currentStep >= VerificationScreen.steps.length;

  @override
  void dispose() {
    _uploadSubscription?.cancel();
    super.dispose();
  }

  // ── Step progression ──────────────────────────────────

  Future<void> _handleCaptureResult(CameraCaptureResult result) async {
    if (_currentStep >= VerificationScreen.steps.length) return;

    final step = VerificationScreen.steps[_currentStep];

    // Start uploading immediately
    _startUpload(step.docType, File(result.filePath));
  }

  void _startUpload(UploadDocType type, File file) {
    setState(() {
      _uploading.add(type);
      _failed.remove(type);
    });

    _uploadSubscription?.cancel();
    _uploadSubscription = DocumentUploadService.instance
        .uploadImage(docType: type, file: file)
        .listen((result) {
          if (!mounted) return;

          if (result.success && result.imageUrl != null) {
            setState(() {
              _uploading.remove(type);
              _uploadedUrls[type] = result.imageUrl!;
            });
            _advanceStep();
          } else if (!result.success) {
            setState(() {
              _uploading.remove(type);
              _failed.add(type);
            });
          }
        });
  }

  void _advanceStep() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _currentStep++);
    });
  }

  void _retryCurrent() {
    // The current step's doc type will be re-captured
    _startCaptureForStep(VerificationScreen.steps[_currentStep]);
  }

  // ── Navigation ────────────────────────────────────────

  Future<void> _startCaptureForStep(VerificationStep step) async {
    final result = await Navigator.of(context).push<CameraCaptureResult>(
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          mode: step.captureMode,
          autoCaptureFace: step.captureMode == CaptureMode.face,
        ),
      ),
    );

    if (result != null && mounted) {
      _handleCaptureResult(result);
    }
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من الهوية'), centerTitle: true),
      body: _allDone ? _buildAllDone() : _buildStepContent(),
    );
  }

  Widget _buildStepContent() {
    final step = VerificationScreen.steps[_currentStep];
    final isUploading = _uploading.contains(step.docType);
    final hasFailed = _failed.contains(step.docType);
    final isDone = _uploadedUrls.containsKey(step.docType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          // Progress indicator
          _buildProgressBar(),

          const SizedBox(height: 40),

          // Step icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              isDone ? Icons.check_circle : step.icon,
              key: ValueKey(isDone),
              size: 80,
              color: isDone
                  ? AppColors.success
                  : hasFailed
                  ? AppColors.error
                  : AppColors.primary,
            ),
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            step.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textMuted),
          ),

          const SizedBox(height: 40),

          // Upload progress or capture button
          if (isUploading) ...[
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 16),
            const Text(
              'جاري الرفع…',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ] else if (hasFailed) ...[
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            const Text(
              'فشل الرفع، حاول مرة أخرى',
              style: TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              label: 'إعادة المحاولة',
              icon: Icons.refresh,
              onTap: _retryCurrent,
            ),
          ] else if (!isDone) ...[
            _buildActionButton(
              label: step.captureMode == CaptureMode.face
                  ? 'التقاط الصورة'
                  : 'فتح الكاميرا',
              icon: Icons.camera_alt_outlined,
              onTap: () => _startCaptureForStep(step),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _pickFromGallery(step),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('اختيار من المعرض'),
            ),
          ] else ...[
            const Icon(Icons.check_circle, color: AppColors.success, size: 48),
            const SizedBox(height: 8),
            const Text(
              'تم الرفع بنجاح ✓',
              style: TextStyle(color: AppColors.success, fontSize: 16),
            ),
          ],

          const Spacer(),

          // Skip / finish buttons
          Row(
            children: [
              if (!isDone && !isUploading)
                TextButton(onPressed: _advanceStep, child: const Text('تخطي')),
              const Spacer(),
              if (isDone && !_allDone)
                ElevatedButton(
                  onPressed: _advanceStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('التالي'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(VerificationScreen.steps.length, (i) {
            final isActive = i == _currentStep;
            final isCompleted = _uploadedUrls.containsKey(
              VerificationScreen.steps[i].docType,
            );

            return Container(
              width: isActive ? 32 : 24,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isCompleted
                    ? AppColors.success
                    : isActive
                    ? AppColors.primary
                    : AppColors.border,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          '${_currentStep + 1} / ${VerificationScreen.steps.length}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGallery(VerificationStep step) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      _startUpload(step.docType, File(picked.path));
    }
  }

  // ── All done screen ───────────────────────────────────

  Widget _buildAllDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 100, color: AppColors.success),
            const SizedBox(height: 24),
            const Text(
              'تم التحقق من الهوية بنجاح',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'تم رفع جميع المستندات. سيتم مراجعتها من قبل فريق الدعم.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(VerificationResult(uploadedUrls: Map.of(_uploadedUrls))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('تم', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
