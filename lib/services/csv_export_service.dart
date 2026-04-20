import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'angle_frame.dart';

class CsvExportService {

  static String _sanitizeFileName(String input) {
    return input
        .replaceAll(RegExp(r'[^\w\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static Future<File> exportExerciseCsv({
    required List<AngleFrame> frames,
  }) async {
    if (frames.isEmpty) {
      throw Exception("No frames recorded");
    }

    final firstFrame = frames.first;
    final angleKeys = <String>{};
    for (final frame in frames) {
      angleKeys.addAll(frame.angles.keys);
    }
    final orderedAngleKeys = angleKeys.toList();

    final headers = [
      "Timestamp",
      "Frame Number",
      "Exercise Name",
      "Heart Rate",
      "RR Intervals",
      ...orderedAngleKeys,
    ];

    List<List<dynamic>> rows = [];
    rows.add(headers);

    for (final frame in frames) {
      rows.add([
        frame.timestamp.toIso8601String(),
        frame.frameNumber,
        frame.exerciseName,
        frame.hr ?? "",
        frame.rr,
        ...orderedAngleKeys.map((key) => frame.angles[key] ?? ""),
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);

    final dir = await getTemporaryDirectory();

    final safeExerciseName = _sanitizeFileName(firstFrame.exerciseName);

    final file = File(
      "${dir.path}/${safeExerciseName}_${DateTime.now().millisecondsSinceEpoch}.csv",
    );

    await file.writeAsString(csvString);

    return file;
  }
}
