import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/pose_detection_service.dart';
import '../utils/pose_painter.dart';
import '../utils/pose_angle_utils.dart';

/// FULL SCREEN PAGE (used in HomeScreen bottom nav)
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: PoseCameraView(),
    );
  }
}

/// REUSABLE CAMERA WIDGET (use this inside ABP runner overlay)
class PoseCameraView extends StatefulWidget {
  final VoidCallback? onClose;
  final Function(Map<String, double>)? onAngles;

  const PoseCameraView({super.key, this.onClose, this.onAngles});

  @override
  State<PoseCameraView> createState() => _PoseCameraViewState();
}

class _PoseCameraViewState extends State<PoseCameraView> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;

  Map<String, double> _angles = {};
  List<Map<String, dynamic>> _landmarks = [];

  bool _isCameraInitialized = false;
  bool _isDetecting = false;

  bool _isClosing = false; // ✅ IMPORTANT

  DateTime _lastFrameTime = DateTime.now();

  int get cameraRotation => _controller?.description.sensorOrientation ?? 0;

  bool get isFrontCamera =>
      _cameras?[_selectedCameraIndex].lensDirection ==
      CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    debugPrint("📷 PoseCameraView init");
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    debugPrint("📷 Initializing camera");

    _cameras = await availableCameras();

    if (_cameras == null || _cameras!.isEmpty) {
      debugPrint("❌ No cameras found");
      return;
    }

    _controller = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    if (!mounted || _isClosing) return;

    debugPrint("✅ Camera initialized: ${_controller!.description.name}");
    debugPrint("📐 Sensor orientation: $cameraRotation");

    setState(() {
      _isCameraInitialized = true;
    });

    _startImageStream();
  }

  void _startImageStream() {
    if (_controller == null) return;

    debugPrint("▶️ Starting image stream");

    _controller!.startImageStream((CameraImage image) async {
      if (_isClosing) return; // ✅ STOP CALLBACKS
      if (_isDetecting) return;

      final now = DateTime.now();

      // throttle to ~10 FPS
      if (now.difference(_lastFrameTime).inMilliseconds < 80) {
        return;
      }
      _lastFrameTime = now;

      _isDetecting = true;

      try {
        final landmarks = await PoseDetectionService.detectPoseStream(
          image,
          cameraRotation,
        );

        if (!mounted || _isClosing) {
          _isDetecting = false;
          return;
        }

        final angles = PoseAngleUtils.calculateAllAngles(landmarks);

        if (!mounted || _isClosing) {
          _isDetecting = false;
          return;
        }

        setState(() {
          _landmarks = landmarks;
          _angles = angles;
        });
        widget.onAngles?.call(angles);
      } catch (e) {
        debugPrint("❌ Pose detection error: $e");
      }

      _isDetecting = false;
    });
  }

  Future<void> _flipCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;
    if (_isClosing) return;

    debugPrint("🔄 Flipping camera...");

    setState(() {
      _isCameraInitialized = false;
      _landmarks = [];
      _angles = {};
    });

    try {
      await _controller?.stopImageStream();
    } catch (_) {}

    try {
      await _controller?.dispose();
    } catch (_) {}

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;

    _controller = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    if (!mounted || _isClosing) return;

    debugPrint("✅ Camera switched to: ${_controller!.description.name}");
    debugPrint("📐 Sensor orientation: $cameraRotation");

    setState(() {
      _isCameraInitialized = true;
    });

    _startImageStream();
  }

  @override
  void dispose() {
    debugPrint("🛑 PoseCameraView dispose");
    _isClosing = true;

    try {
      _controller?.stopImageStream();
    } catch (_) {}

    // ✅ DELAY DISPOSE to avoid CameraX observer crash
    Future.delayed(const Duration(milliseconds: 200), () {
      try {
        _controller?.dispose();
      } catch (_) {}
    });

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CameraPreview(_controller!),
        ),

        Positioned.fill(
          child: CustomPaint(
            painter: PosePainter(
              landmarks: _landmarks,
              isFrontCamera: isFrontCamera,
              rotation: cameraRotation,
              angles: _angles,
            ),
          ),
        ),

        // TOP BUTTONS
        Positioned(
          top: 40,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.onClose != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                    ),
                    onPressed: widget.onClose,
                  ),
                )
              else
                const SizedBox(width: 50),

              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.flip_camera_android_rounded,
                    color: Colors.white,
                  ),
                  onPressed: _flipCamera,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
