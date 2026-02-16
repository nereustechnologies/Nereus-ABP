class AngleFrame {
  final DateTime timestamp;
  final int frameNumber;
  final String exerciseName;
  final Map<String, double> angles;
  final int? hr;
  final String rr;

  AngleFrame({
    required this.timestamp,
    required this.frameNumber,
    required this.exerciseName,
    required this.angles,
    required this.hr,
    required this.rr,
  });
}
