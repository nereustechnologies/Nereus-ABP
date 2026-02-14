import 'abp_models.dart';

final List<AbpStep> abpSteps = [
  const AbpStep(
    blockName: "BLOCK 0",
    exerciseName: "Quiet Standing Baseline",
    instructions:
        "Stand still.\n\n• Feet flat\n• Weight even\n• Eyes open\n• Arms relaxed\n\nConfirm pain + history details.",
    type: AbpStepType.infoOnly,
    durationSeconds: 30,
  ),

  const AbpStep(
    blockName: "BLOCK 0",
    exerciseName: "Mood + Psych Entry",
    instructions:
        "Sit down.\n\nEnter:\n• Mood\n• Training intent (recovery/build/test)\n\nSystem stores context.",
    type: AbpStepType.infoOnly,
    durationSeconds: 30,
  ),

  const AbpStep(
    blockName: "BLOCK 1",
    exerciseName: "Arm Circumduction",
    instructions:
        "Do forward arm circles for 15 reps.\nThen backward circles for 15 reps.\n\nKeep posture tall.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 40,
  ),

  const AbpStep(
    blockName: "BLOCK 1",
    exerciseName: "Straight Leg Raise",
    instructions:
        "Lie on your back.\n\nKeep knee locked.\nRaise leg to about 60°.\n\n15 reps per leg.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 50,
  ),

  const AbpStep(
    blockName: "BLOCK 1",
    exerciseName: "FABER / FADIR",
    instructions:
        "Lie supine.\nHip + knee at 90°.\nMove foot inward/outward.\n\n15 reps.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 50,
  ),

  const AbpStep(
    blockName: "BLOCK 1",
    exerciseName: "Ankle Dorsiflexion (Knee to Wall)",
    instructions:
        "Half kneeling or lunge.\nTry to touch knee to wall without lifting heel.\n\nHold 15 sec each leg.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 40,
  ),

  const AbpStep(
    blockName: "BLOCK 1",
    exerciseName: "Cobra (Spinal Extension)",
    instructions:
        "Lie prone.\nPush up until arms straight.\nHold 15 seconds.\n\nStop if pain.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 25,
  ),

  const AbpStep(
    blockName: "BLOCK 2",
    exerciseName: "Bodyweight Squats",
    instructions:
        "Squat to 90°.\nUse stool/roller if needed.\n\n30 sec work, 15 sec rest (x2).",
    type: AbpStepType.cameraExercise,
    durationSeconds: 75,
  ),

  const AbpStep(
    blockName: "BLOCK 2",
    exerciseName: "Reverse Lunges",
    instructions:
        "Step backward into lunge.\nKeep chest tall.\n\n10 reps per leg.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 60,
  ),

  const AbpStep(
    blockName: "BLOCK 2",
    exerciseName: "Calf Raises",
    instructions:
        "Stand tall.\nRaise heels up slowly.\n\n15 reps.\nControl the descent.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 35,
  ),

  const AbpStep(
    blockName: "BLOCK 3",
    exerciseName: "Push-ups",
    instructions:
        "Do 15 push-ups.\n\nAlternative:\n• Incline push-ups\n• Knee push-ups",
    type: AbpStepType.cameraExercise,
    durationSeconds: 55,
  ),

  const AbpStep(
    blockName: "BLOCK 3",
    exerciseName: "Band Shoulder Abduction",
    instructions:
        "Hold resistance band.\nRaise arms sideways.\n\n15 reps.\nControl movement.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 45,
  ),

  const AbpStep(
    blockName: "BLOCK 3",
    exerciseName: "Shoulder Internal/External Rotation",
    instructions:
        "Keep elbow close to body.\nRotate inward/outward.\n\n15 reps each side.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 50,
  ),

  const AbpStep(
    blockName: "BLOCK 4",
    exerciseName: "Treadmill Jog",
    instructions:
        "Jog at 8.5 km/hr.\nDuration: 90 sec.\n\nFocus on controlled breathing.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 90,
  ),

  const AbpStep(
    blockName: "BLOCK 5",
    exerciseName: "Plank",
    instructions:
        "Hold plank.\n\nKeep hips level.\nAvoid sagging.\n\n45 sec to 90 sec.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 60,
  ),

  const AbpStep(
    blockName: "BLOCK 6",
    exerciseName: "Jumping Jacks",
    instructions:
        "Do 30 reps.\n\nKeep breathing steady.\nStop if cramps/pain.",
    type: AbpStepType.cameraExercise,
    durationSeconds: 40,
  ),

  const AbpStep(
    blockName: "BLOCK 7",
    exerciseName: "Cooldown + Final Psych",
    instructions:
        "Sit down.\n\nSystem captures HR recovery + HRV rebound.\nEnter RPE + fatigue + pain flags.",
    type: AbpStepType.infoOnly,
    durationSeconds: 60,
  ),
];
