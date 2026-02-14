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

      final result = await _channel.invokeMethod("detectPoseStream", {
        "width": image.width,
        "height": image.height,
        "rotation": rotation,
        "timestamp": DateTime.now().millisecondsSinceEpoch,

        "plane0": image.planes[0].bytes,
        "plane1": image.planes[1].bytes,
        "plane2": image.planes[2].bytes,

        "stride0": image.planes[0].bytesPerRow,
        "stride1": image.planes[1].bytesPerRow,
        "stride2": image.planes[2].bytesPerRow,

        "pixelStride1": image.planes[1].bytesPerPixel,
        "pixelStride2": image.planes[2].bytesPerPixel,
      });

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
