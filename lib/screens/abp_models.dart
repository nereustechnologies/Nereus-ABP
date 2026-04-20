import '../utils/pose_angle_utils.dart';

enum AbpStepType {
  infoOnly,
  cameraExercise,
  rest,
}

class AbpStep {
  final String blockName;
  final String exerciseName;
  final String instructions;
  final AbpStepType type;
  final CameraView? cameraView;

  final int countdownSeconds;
  final int durationSeconds;

  const AbpStep({
    required this.blockName,
    required this.exerciseName,
    required this.instructions,
    required this.type,
    this.cameraView,
    this.countdownSeconds = 5,
    this.durationSeconds = 30,
  });
}
