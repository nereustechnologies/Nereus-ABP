import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'abp_session_data.dart';
import 'abp_models.dart';
import 'abp_transition_screen.dart';
import 'camera_screen.dart';

import '../services/exercise_data_recorder.dart';
import '../services/csv_export_service.dart';
import '../services/s3_upload_service.dart';

class AbpSessionRunner extends StatefulWidget {
  final String userId;

  const AbpSessionRunner({super.key, required this.userId});

  @override
  State<AbpSessionRunner> createState() => _AbpSessionRunnerState();
}

class _AbpSessionRunnerState extends State<AbpSessionRunner> {
  int currentStepIndex = 0;

  bool isCountingDown = true;
  bool showCameraMode = false;
  bool isPaused = false;
  bool isSessionCreating = true;

  int countdown = 5;
  int timerSeconds = 0;

  Timer? _timer;

  AbpStep get step => abpSteps[currentStepIndex];

  final ExerciseDataRecorder recorder = ExerciseDataRecorder();

  String? sessionId;
  String? lastUploadedCsvKey;

  final supabase = Supabase.instance.client;

  DateTime? lastPoseTime;
  bool get isPoseMissing {
    if (!showCameraMode) return false;
    if (lastPoseTime == null) return true;

    return DateTime.now().difference(lastPoseTime!).inSeconds >= 2;
  }

  static const int minFramesRequired = 5;

  // ==============================
  // INIT
  // ==============================

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ==============================
  // CREATE SESSION
  // ==============================

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

      debugPrint("✅ Session Created: $sessionId");

      setState(() {
        isSessionCreating = false;
      });

      _startCountdown();
    } catch (e) {
      debugPrint("❌ Failed to create session: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to start session: $e")),
        );
      }
    }
  }

  // ==============================
  // SESSION CONTROL
  // ==============================

  void _pauseSession() {
    _timer?.cancel();

    setState(() {
      isPaused = true;
      showCameraMode = false;
    });
  }

  void _resumeSession() {
    setState(() {
      isPaused = false;
    });

    if (isCountingDown) {
      _resumeCountdown();
    } else {
      setState(() => showCameraMode = true);
      _resumeExerciseTimer();
    }
  }

  // ==============================
  // COUNTDOWN
  // ==============================

  void _startCountdown() {
    _timer?.cancel();

    setState(() {
      isCountingDown = true;
      showCameraMode = false;
      countdown = step.countdownSeconds;
      isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (isPaused) return;

      if (countdown <= 1) {
        t.cancel();
        _startCameraPhase();
      } else {
        setState(() => countdown--);
      }
    });
  }

  void _resumeCountdown() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (isPaused) return;

      if (countdown <= 1) {
        t.cancel();
        _startCameraPhase();
      } else {
        setState(() => countdown--);
      }
    });
  }

  // ==============================
  // CAMERA PHASE
  // ==============================

  void _startCameraPhase() {
    recorder.clear();
    lastPoseTime = null;

    setState(() {
      isCountingDown = false;
      showCameraMode = true;
      timerSeconds = step.durationSeconds;
    });

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (isPaused) return;

      if (timerSeconds <= 1) {
        t.cancel();

        setState(() => showCameraMode = false);

        await Future.delayed(const Duration(milliseconds: 100));
        await _finishExerciseAndGoNext();
      } else {
        setState(() => timerSeconds--);
      }
    });
  }

  void _resumeExerciseTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (isPaused) return;

      if (timerSeconds <= 1) {
        t.cancel();

        setState(() => showCameraMode = false);

        await Future.delayed(const Duration(milliseconds: 100));
        await _finishExerciseAndGoNext();
      } else {
        setState(() => timerSeconds--);
      }
    });
  }

  // ==============================
  // EXPORT + UPLOAD + DB INSERT
  // ==============================

  Future<void> _finishExerciseAndGoNext() async {
    try {
      if (sessionId == null) {
        debugPrint("❌ No sessionId, skipping exercise save.");
        await _goToNextStep();
        return;
      }

      if (recorder.frames.length < minFramesRequired) {
        debugPrint("⚠️ Not enough frames (${recorder.frames.length}), skipping.");
        lastUploadedCsvKey = null;
        recorder.clear();
        await _goToNextStep();
        return;
      }

      final csvFile = await CsvExportService.exportExerciseCsv(
        frames: recorder.frames,
      );

      final exerciseId = "${step.blockName}_${step.exerciseName}"
          .replaceAll(" ", "_")
          .replaceAll("/", "_")
          .replaceAll(":", "_");

      final uploadedKey = await S3UploadService.uploadCsv(
        file: csvFile,
        userId: widget.userId,
        sessionId: sessionId!,
        exerciseId: exerciseId,
      );

      final fileSize = await csvFile.length();

      await supabase.from("exercises").insert({
        "session_id": sessionId!,
        "block_number": currentStepIndex,
        "block_name": step.blockName,
        "exercise_name": step.exerciseName,
        "duration_seconds": step.durationSeconds,
        "s3_bucket": S3UploadService.bucketName,
        "s3_key": uploadedKey,
        "file_size_bytes": fileSize,
        "frame_count": recorder.frames.length,
      });

      lastUploadedCsvKey = uploadedKey;

      debugPrint("✅ Exercise saved to DB");
    } catch (e) {
      debugPrint("❌ Error during export/upload/db insert: $e");
      lastUploadedCsvKey = null;
    }

    recorder.clear();
    await _goToNextStep();
  }

  // ==============================
  // COMPLETE SESSION
  // ==============================

  Future<void> _completeSession() async {
    final id = sessionId;
    if (id == null) return;

    try {
      await supabase.from("sessions").update({
        "completed_at": DateTime.now().toIso8601String(),
      }).eq("id", id);

      debugPrint("✅ Session marked complete");
    } catch (e) {
      debugPrint("❌ Failed to update session completion: $e");
    }
  }

  // ==============================
  // NEXT STEP
  // ==============================

  Future<void> _goToNextStep() async {
    if (currentStepIndex >= abpSteps.length - 1) {
      await _completeSession();
      Navigator.pop(context);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbpTransitionScreen(
          title: "Exercise Complete",
          message: "Take your time. Continue when ready.",
          csvKey: lastUploadedCsvKey,
        ),
      ),
    );

    setState(() {
      currentStepIndex++;
      isPaused = false;
      lastUploadedCsvKey = null;
    });

    _startCountdown();
  }

  // ==============================
  // ANGLE FILTER
  // ==============================

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

  // ==============================
  // UI
  // ==============================

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // CAMERA MODE
            if (showCameraMode)
              Positioned.fill(
                child: PoseCameraView(
                  onClose: _pauseSession,
                  onAngles: (angles) {
                    if (!isPaused && showCameraMode) {
                      final cleanAngles = _sanitizeAngles(angles);

                      if (cleanAngles.isEmpty) return;

                      lastPoseTime = DateTime.now();

                      recorder.recordFrame(
                        exerciseName: step.exerciseName,
                        angles: cleanAngles,
                      );

                      setState(() {});
                    }
                  },
                ),
              ),

            // WARNING OVERLAY IF NO POSE
            if (showCameraMode && isPoseMissing)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        "⚠️ No pose detected.\nStep into frame.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // INSTRUCTION MODE
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
                        isCountingDown
                            ? "Starting in"
                            : (isPaused ? "Paused" : "Time Remaining"),
                        isCountingDown
                            ? countdown.toString()
                            : timerSeconds.toString(),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  if (isPaused) {
                                    _resumeSession();
                                  } else {
                                    _pauseSession();
                                  }
                                },
                                child: Text(
                                  isPaused ? "Resume" : "Pause",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  _timer?.cancel();

                                  setState(() {
                                    showCameraMode = false;
                                  });

                                  await Future.delayed(
                                    const Duration(milliseconds: 100),
                                  );

                                  await _finishExerciseAndGoNext();
                                },
                                child: const Text(
                                  "Skip",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // BOTTOM OVERLAY
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
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                step.exerciseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 14),

              _bigCounter(
                isPaused ? "Paused" : "Time Remaining",
                timerSeconds.toString(),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          if (isPaused) {
                            _resumeSession();
                          } else {
                            _pauseSession();
                          }
                        },
                        child: Text(
                          isPaused ? "Resume" : "Pause",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          _timer?.cancel();

                          setState(() {
                            showCameraMode = false;
                          });

                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );

                          await _finishExerciseAndGoNext();
                        },
                        child: const Text(
                          "Skip",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Center(
                child: Text(
                  isPoseMissing
                      ? "⚠️ Pose not detected"
                      : "Pose tracking active",
                  style: TextStyle(
                    color: isPoseMissing ? Colors.redAccent : Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Center(
                child: Text(
                  "Frames captured: ${recorder.frames.length}",
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
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
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
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
