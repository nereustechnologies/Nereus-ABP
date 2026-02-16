import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'angle_frame.dart';

class CsvExportService {
  static Future<File> exportExerciseCsv({
    required List<AngleFrame> frames,
  }) async {
    if (frames.isEmpty) {
      throw Exception("No frames recorded");
    }

    final firstFrame = frames.first;

    final headers = [
      "Timestamp",
      "Frame Number",
      "Exercise Name",
      "Heart Rate",
      "RR Intervals",
      ...firstFrame.angles.keys,
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
        ...headers
            .skip(5)
            .map((key) => frame.angles[key] ?? ""),
      ]);
    }

    final csvString =
        const ListToCsvConverter().convert(rows);

    final dir = await getTemporaryDirectory();

    final file = File(
      "${dir.path}/${firstFrame.exerciseName}_${DateTime.now().millisecondsSinceEpoch}.csv",
    );

    await file.writeAsString(csvString);

    return file;
  }
}
