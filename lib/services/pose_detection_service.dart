import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PoseDetectionService {
  static const MethodChannel _channel = MethodChannel("nereus/pose_detection");

  static Future<List<Map<String, dynamic>>> detectPoseStream(
    CameraImage image,
    int rotation,
  ) async {
    try {
      debugPrint(
        "📡 Sending to native | w=${image.width} h=${image.height} rot=$rotation",
      );

      final planes = image.planes;

      final args = <String, dynamic>{
        "width": image.width,
        "height": image.height,
        "rotation": rotation,
        "timestamp": DateTime.now().millisecondsSinceEpoch,

        "plane0": planes[0].bytes,
        "plane1": planes[1].bytes,

        "stride0": planes[0].bytesPerRow,
        "stride1": planes[1].bytesPerRow,

        "pixelStride1": planes[1].bytesPerPixel,
      };

      // Only on Android (or any device with 3 planes)
      if (planes.length > 2) {
        args["plane2"] = planes[2].bytes;
        args["stride2"] = planes[2].bytesPerRow;
        args["pixelStride2"] = planes[2].bytesPerPixel;
      }

      final result = await _channel.invokeMethod("detectPoseStream", args);


      if (result == null) return [];

      final List<dynamic> rawList = result as List<dynamic>;

      return rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint("❌ MethodChannel detectPoseStream error: $e");
      return [];
    }
  }
}
