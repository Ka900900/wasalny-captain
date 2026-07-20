import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:waslny_captain/core/theme/app_theme.dart';
import 'package:waslny_captain/features/verification/widgets/overlay_painter.dart';

/// The mode of capture: document (rectangle) or face (oval).
enum CaptureMode { document, face }

/// Result returned by [CameraScreen] when the user captures an image.
class CameraCaptureResult {
  final String filePath;
  final CaptureMode mode;

  const CameraCaptureResult({required this.filePath, required this.mode});
}

/// Full‑screen custom camera with:
/// - Interactive overlay mask (rectangle for documents, oval for face)
/// - ML Kit face detection for selfie mode
/// - Auto‑capture when valid face is detected (optional)
/// - Flash toggle & switch camera buttons
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.mode,
    this.autoCaptureFace = true,
  });

  /// Capture mode — document or face.
  final CaptureMode mode;

  /// When `true` and [mode] == [CaptureMode.face], automatically captures
  /// once a face with high confidence is detected.
  final bool autoCaptureFace;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // ── Camera ────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;
  bool _flashOn = false;
  int _selectedCamera = 0; // 0 = back, 1 = front

  // ── ML Kit Face Detection ─────────────────────────────
  FaceDetector? _faceDetector;
  bool _faceDetected = false;
  bool _isProcessing = false;

  // ── State ─────────────────────────────────────────────
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();

    if (widget.mode == CaptureMode.face) {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: false,
          enableContours: false,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceDetector?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactiveResume) {
      _controller?.resumePreview();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera available');
        return;
      }

      // For face/selfie, prefer front camera.
      if (widget.mode == CaptureMode.face) {
        final frontIdx = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        if (frontIdx >= 0) _selectedCamera = frontIdx;
      }

      await _startCamera(_selectedCamera);
    } catch (e) {
      setState(() => _error = 'Failed to initialise camera: $e');
    }
  }

  Future<void> _startCamera(int index) async {
    await _controller?.dispose();
    final camera = _cameras[index];

    _controller = CameraController(
      camera,
      // Use medium resolution for speed
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() => _cameraReady = true);
      _startFrameProcessing();
    }
  }

  /// Listen to every frame for face detection.
  void _startFrameProcessing() {
    if (widget.mode != CaptureMode.face) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    _controller!.startImageStream((image) {
      if (_isProcessing || _capturing) return;
      _isProcessing = true;
      _processFrame(image);
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      // Build InputImage from camera image
      final inputImage = _inputImageFromCamera(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);
      final detected =
          faces.isNotEmpty &&
          faces.any(
            (f) => f.smilingProbability == null || f.smilingProbability! > 0.3,
          );

      if (mounted) {
        setState(() => _faceDetected = detected);
      }

      // Auto‑capture if face detected and auto mode enabled
      if (detected && widget.autoCaptureFace && !_capturing) {
        await _capturePhoto();
      }
    } catch (e) {
      debugPrint('[CameraScreen] Frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Convert CameraImage to ML Kit InputImage.
  InputImage? _inputImageFromCamera(CameraImage image) {
    final camera = _cameras[_selectedCamera];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (sensorOrientation == 90) {
      rotation = InputImageRotation.rotation90deg;
    } else if (sensorOrientation == 180) {
      rotation = InputImageRotation.rotation180deg;
    } else if (sensorOrientation == 270) {
      rotation = InputImageRotation.rotation270deg;
    } else {
      rotation = InputImageRotation.rotation0deg;
    }

    final format = image.format.group == ImageFormatGroup.yuv420.name
        ? InputImageFormat.yuv_420_888
        : InputImageFormat.nv21;

    final planes = image.planes
        .map(
          (plane) => InputImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          ),
        )
        .toList();

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  // ── Capture ───────────────────────────────────────────

  Future<void> _capturePhoto() async {
    if (_controller == null || !_cameraReady || _capturing) return;

    setState(() => _capturing = true);

    try {
      // Stop image stream to free resources during capture
      if (widget.mode == CaptureMode.face) {
        _controller?.stopImageStream();
      }

      final xfile = await _controller!.takePicture();
      if (!mounted) return;

      Navigator.of(
        context,
      ).pop(CameraCaptureResult(filePath: xfile.path, mode: widget.mode));
    } catch (e) {
      debugPrint('[CameraScreen] Capture error: $e');
      setState(() {
        _capturing = false;
        _error = 'Failed to take picture: $e';
      });
      // Restart frame processing on failure
      if (widget.mode == CaptureMode.face) {
        _startFrameProcessing();
      }
    }
  }

  // ── UI ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 64),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraReady || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        // Camera preview
        CameraPreview(_controller!),

        // Overlay mask
        if (widget.mode == CaptureMode.face)
          CustomPaint(
            painter: FaceOverlayPainter(
              faceDetected: _faceDetected,
              faceDetectedColor: AppColors.primary,
            ),
            size: Size.infinite,
          )
        else
          CustomPaint(
            painter: DocumentOverlayPainter(borderColor: AppColors.primary),
            size: Size.infinite,
          ),

        // Face detection status
        if (widget.mode == CaptureMode.face && _faceDetected)
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: Text(
              '✅ Face detected',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ),

        // Guide text
        Positioned(
          bottom: 100,
          left: 32,
          right: 32,
          child: Text(
            widget.mode == CaptureMode.face
                ? 'Place your face inside the oval frame'
                : 'Fit the document inside the rectangle frame',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        ),

        // Top toolbar
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              // Flash toggle
              IconButton(
                icon: Icon(
                  _flashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _toggleFlash,
              ),
              // Switch camera (only for document mode)
              if (_cameras.length > 1 && widget.mode == CaptureMode.document)
                IconButton(
                  icon: const Icon(
                    Icons.flip_camera_android,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _switchCamera,
                ),
            ],
          ),
        ),

        // Capture button (document mode only — face uses auto‑capture)
        if (widget.mode == CaptureMode.document)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _capturing ? null : _capturePhoto,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _capturing ? 56 : 72,
                  height: _capturing ? 56 : 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _capturing ? Colors.grey : Colors.white,
                    border: Border.all(color: Colors.white70, width: 4),
                  ),
                  child: _capturing
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),

        // Processing overlay
        if (_capturing) Container(color: Colors.black38),
      ],
    );
  }

  void _toggleFlash() {
    _controller?.setFlashMode(_flashOn ? FlashMode.off : FlashMode.torch);
    setState(() => _flashOn = !_flashOn);
  }

  Future<void> _switchCamera() async {
    final next = (_selectedCamera + 1) % _cameras.length;
    _selectedCamera = next;
    await _startCamera(next);
  }
}
