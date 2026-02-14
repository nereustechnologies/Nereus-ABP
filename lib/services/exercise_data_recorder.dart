import 'angle_frame.dart';

class ExerciseDataRecorder {
  final List<AngleFrame> _frames = [];
  int _frameCounter = 0;

  void recordFrame({
    required String exerciseName,
    required Map<String, double> angles,
  }) {
    _frameCounter++;

    _frames.add(
      AngleFrame(
        timestamp: DateTime.now(),
        frameNumber: _frameCounter,
        exerciseName: exerciseName,
        angles: Map.from(angles),
      ),
    );
  }

  List<AngleFrame> get frames => List.unmodifiable(_frames);

  void clear() {
    _frames.clear();
    _frameCounter = 0;
  }

  bool get isEmpty => _frames.isEmpty;
}
