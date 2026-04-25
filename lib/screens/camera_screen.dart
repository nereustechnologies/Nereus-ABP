import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/pose_detection_service.dart';
import '../utils/pose_painter.dart';
import '../utils/pose_angle_utils.dart';

/// FULL SCREEN PAGE (used in HomeScreen bottom nav)
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraView _selectedView = CameraView.front;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PoseCameraView(view: _selectedView),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: _ViewModeButton(
                      label: 'Front View',
                      isSelected: _selectedView == CameraView.front,
                      onTap: () {
                        if (_selectedView == CameraView.front) return;
                        setState(() {
                          _selectedView = CameraView.front;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ViewModeButton(
                      label: 'Side View',
                      isSelected: _selectedView == CameraView.side,
                      onTap: () {
                        if (_selectedView == CameraView.side) return;
                        setState(() {
                          _selectedView = CameraView.side;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.9)
              : Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white24,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// REUSABLE CAMERA WIDGET (use this inside ABP runner overlay)
class PoseCameraView extends StatefulWidget {
  final VoidCallback? onClose;
  final Function(Map<String, double>)? onAngles;
  final CameraView view;

  const PoseCameraView({
    super.key,
    this.onClose,
    this.onAngles,
    this.view = CameraView.front,
  });

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
    PoseAngleUtils.reset();
    _initializeCamera();
  }

  @override
  void didUpdateWidget(covariant PoseCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.view != widget.view) {
      PoseAngleUtils.reset();
      setState(() {
        _angles = {};
      });
    }
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
      if (now.difference(_lastFrameTime).inMilliseconds < 16) {
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
        
        final angles = PoseAngleUtils.calculateAllAngles(
          landmarks,
          view: widget.view,
        );

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
    PoseAngleUtils.reset();
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
