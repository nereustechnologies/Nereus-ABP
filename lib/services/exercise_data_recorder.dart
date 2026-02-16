import 'angle_frame.dart';
import 'polar_data_service.dart';

class ExerciseDataRecorder {
  final List<AngleFrame> _frames = [];
  int _frameCounter = 0;

  void recordFrame({
    required String exerciseName,
    required Map<String, double> angles,
  }) {
    _frameCounter++;

    final polar = PolarDataService.instance.getLatest();

    final int hr = (polar["hr"] as int?) ?? 0;

    final List<double> rrList = (polar["rr"] as List<dynamic>? ?? [])
        .map((e) => (e as num).toDouble())
        .toList();

    _frames.add(
      AngleFrame(
        timestamp: DateTime.now(),
        frameNumber: _frameCounter,
        exerciseName: exerciseName,
        angles: Map.from(angles),
        hr: hr,
        rr: rrList.map((e) => e.toStringAsFixed(3)).join("|"),
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
