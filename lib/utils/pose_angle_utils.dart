import 'dart:math';

class PoseAngleUtils {
  static double _angleBetweenPoints(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    Map<String, dynamic> c,
  ) {
    final abX = (a["x"] as num).toDouble() - (b["x"] as num).toDouble();
    final abY = (a["y"] as num).toDouble() - (b["y"] as num).toDouble();

    final cbX = (c["x"] as num).toDouble() - (b["x"] as num).toDouble();
    final cbY = (c["y"] as num).toDouble() - (b["y"] as num).toDouble();

    final dot = (abX * cbX) + (abY * cbY);

    final magAB = sqrt(abX * abX + abY * abY);
    final magCB = sqrt(cbX * cbX + cbY * cbY);

    if (magAB == 0 || magCB == 0) return 0;

    final cosAngle = (dot / (magAB * magCB)).clamp(-1.0, 1.0);
    return acos(cosAngle) * (180 / pi);
  }

  static Map<String, double> calculateAllAngles(List<Map<String, dynamic>> lm) {
    if (lm.length < 33) return {};

    Map<String, dynamic> p(int i) => lm[i];

    return {
      // Elbows
      "leftElbow": _angleBetweenPoints(p(11), p(13), p(15)),
      "rightElbow": _angleBetweenPoints(p(12), p(14), p(16)),

      // Shoulders
      "leftShoulder": _angleBetweenPoints(p(13), p(11), p(23)),
      "rightShoulder": _angleBetweenPoints(p(14), p(12), p(24)),

      // Hips
      "leftHip": _angleBetweenPoints(p(11), p(23), p(25)),
      "rightHip": _angleBetweenPoints(p(12), p(24), p(26)),

      // Knees
      "leftKnee": _angleBetweenPoints(p(23), p(25), p(27)),
      "rightKnee": _angleBetweenPoints(p(24), p(26), p(28)),

      // Ankles
      "leftAnkle": _angleBetweenPoints(p(25), p(27), p(31)),
      "rightAnkle": _angleBetweenPoints(p(26), p(28), p(32)),
    };
  }
}
