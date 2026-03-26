import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'abp_session_data.dart';
import 'abp_models.dart';
import 'abp_transition_screen.dart';
import 'camera_screen.dart';

import '../services/exercise_data_recorder.dart';
import '../services/csv_export_service.dart';
import '../services/s3_upload_service.dart';
import '../services/polar_data_service.dart';

class AbpSessionRunner extends StatefulWidget {
  final String userId;

  const AbpSessionRunner({super.key, required this.userId});

  @override
  State<AbpSessionRunner> createState() => _AbpSessionRunnerState();
}

class _AbpSessionRunnerState extends State<AbpSessionRunner> {
  int currentStepIndex = 0;

  bool showCameraMode = false;
  bool isPaused = false;
  bool isSessionCreating = true;

  bool hasStartedExercise = false;
  bool showResumeButton = false;

  bool isFinishingStep = false;
  bool isSavingExercise = false;

  final ExerciseDataRecorder recorder = ExerciseDataRecorder();

  String? sessionId;
  String? lastUploadedCsvKey;

  final supabase = Supabase.instance.client;

  DateTime? lastPoseTime;

  AbpStep get step => abpSteps[currentStepIndex];

  static const int minFramesRequired = 5;

  bool get isPoseMissing {
    if (!showCameraMode) return false;
    if (lastPoseTime == null) return true;
    return DateTime.now().difference(lastPoseTime!).inSeconds >= 2;
  }

  @override
  void initState() {
    super.initState();
    PolarDataService.instance.reset();
    _createSession();
  }

  Future<void> _createSession() async {
    try {
      final sessionRow = await supabase
          .from("sessions")
          .insert({
            "user_id": widget.userId,
            "started_at": DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      sessionId = sessionRow["id"];

      if (!mounted) return;

      setState(() {
        isSessionCreating = false;
      });
    } catch (e) {
      debugPrint("Failed to create session $e");
    }
  }

  void _resetExerciseCapture({required bool clearFrames}) {
    lastPoseTime = null;
    isFinishingStep = false;

    if (clearFrames) {
      recorder.clear();
    }
  }

  void _startExercise() {
    _resetExerciseCapture(clearFrames: true);

    setState(() {
      hasStartedExercise = true;
      isPaused = false;
      showCameraMode = true;
      showResumeButton = false;
    });
  }

  void _resumeExercise() {
    _resetExerciseCapture(clearFrames: false);

    setState(() {
      hasStartedExercise = true;
      isPaused = false;
      showCameraMode = true;
    });
  }

  void _pauseSession() {
    setState(() {
      isPaused = true;
      showCameraMode = false;
      showResumeButton = true;
    });
  }

  Future<void> _onNextPressed() async {
    if (isFinishingStep) return;

    setState(() {
      isFinishingStep = true;
      isSavingExercise = true;
      showCameraMode = false;
    });

    await Future.delayed(const Duration(milliseconds: 50));

    _finishExerciseAsync();
  }

  Future<void> _finishExerciseAsync() async {
    try {
      final id = sessionId;

      if (id == null) {
        await _goToNextStep();
        return;
      }

      if (recorder.frames.length < minFramesRequired) {
        recorder.clear();
        await _goToNextStep();
        return;
      }

      final framesCopy = List.of(recorder.frames);

      final csvFile = await CsvExportService.exportExerciseCsv(
        frames: framesCopy,
      );

      String sanitize(String s) {
        return s
            .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
            .replaceAll(RegExp(r'_+'), '_');
      }

      final exerciseId = sanitize("${step.blockName}_${step.exerciseName}");

      final uploadFuture = S3UploadService.uploadCsv(
        file: csvFile,
        userId: widget.userId,
        sessionId: id,
        exerciseId: exerciseId,
      );

      final uploadedKey = await uploadFuture;

      final fileSize = await csvFile.length();

      await supabase.from("exercises").insert({
        "session_id": id,
        "block_number": currentStepIndex,
        "block_name": step.blockName,
        "exercise_name": step.exerciseName,
        "duration_seconds": step.durationSeconds,
        "s3_bucket": S3UploadService.bucketName,
        "s3_key": uploadedKey,
        "file_size_bytes": fileSize,
        "frame_count": framesCopy.length,
      });

      lastUploadedCsvKey = uploadedKey;
    } catch (e) {
      debugPrint("Save error $e");
    }

    recorder.clear();

    await _goToNextStep();
  }

  Future<void> _onSkipPressed() async {
    if (isFinishingStep) return;

    setState(() {
      isFinishingStep = true;
      showCameraMode = false;
    });

    recorder.clear();

    await _goToNextStep();
  }

  Future<void> _completeSession() async {
    final id = sessionId;
    if (id == null) return;

    await supabase.from("sessions").update({
      "completed_at": DateTime.now().toIso8601String(),
    }).eq("id", id);
  }

  Future<void> _goToNextStep() async {
    if (currentStepIndex >= abpSteps.length - 1) {
      await _completeSession();
      if (mounted) Navigator.pop(context);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbpTransitionScreen(
          title: "Exercise Complete",
          message: "Continue when ready.",
          csvKey: lastUploadedCsvKey,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      currentStepIndex++;

      recorder.clear();
      lastPoseTime = null;

      showCameraMode = false;
      isPaused = false;

      hasStartedExercise = false;
      showResumeButton = false;

      isSavingExercise = false;
      isFinishingStep = false;
    });
  }

  Map<String, double> _sanitizeAngles(Map<String, double> angles) {
    final clean = <String, double>{};

    for (final entry in angles.entries) {
      final v = entry.value;

      if (v.isNaN || v.isInfinite) continue;
      if (v < 0) continue;
      if (v > 360) continue;

      clean[entry.key] = v;
    }

    return clean;
  }

  @override
  Widget build(BuildContext context) {
    if (isSessionCreating) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (isSavingExercise) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Saving exercise...",
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (showCameraMode)
              Positioned.fill(
                child: PoseCameraView(
                  onClose: _pauseSession,
                  onAngles: (angles) {
                    if (isFinishingStep) return;
                    if (isPaused) return;
                    if (!showCameraMode) return;

                    final cleanAngles = _sanitizeAngles(angles);

                    if (cleanAngles.isEmpty) return;

                    lastPoseTime = DateTime.now();

                    recorder.recordFrame(
                      exerciseName: step.exerciseName,
                      angles: cleanAngles,
                    );

                    if (mounted) setState(() {});
                  },
                ),
              ),

            if (!showCameraMode)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.blockName,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        step.exerciseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        step.instructions,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),

                      _bigCounter(
                        "Frames",
                        recorder.frames.length.toString(),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          if (showResumeButton)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _resumeExercise,
                                child: const Text("Resume"),
                              ),
                            ),

                          if (showResumeButton) const SizedBox(width: 12),

                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: _startExercise,
                              child: const Text("Start"),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          onPressed: _onSkipPressed,
                          child: const Text("Skip"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (showCameraMode) _bottomOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _bottomOverlay() {
    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.20,
      maxChildSize: 0.55,
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Text(
                step.exerciseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 14),

              _bigCounter(
                "Frames",
                recorder.frames.length.toString(),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text("Next"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: _onSkipPressed,
                      child: const Text("Skip"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bigCounter(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}