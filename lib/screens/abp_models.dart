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

  final int countdownSeconds;
  final int durationSeconds;

  const AbpStep({
    required this.blockName,
    required this.exerciseName,
    required this.instructions,
    required this.type,
    this.countdownSeconds = 5,
    this.durationSeconds = 30,
  });
}
