import 'dart:math';

class Vec3 {
  final double x, y, z;

  Vec3(this.x, this.y, this.z);

  Vec3 operator -(Vec3 other) =>
      Vec3(x - other.x, y - other.y, z - other.z);
}

// ================= VECTOR MATH =================

double dot(Vec3 a, Vec3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

Vec3 cross(Vec3 a, Vec3 b) => Vec3(
      a.y * b.z - a.z * b.y,
      a.z * b.x - a.x * b.z,
      a.x * b.y - a.y * b.x,
    );

double magnitude(Vec3 v) => sqrt(dot(v, v));

Vec3 normalize(Vec3 v) {
  final mag = magnitude(v);
  return mag == 0 ? v : Vec3(v.x / mag, v.y / mag, v.z / mag);
}

// ================= HELPERS =================

Vec3 toVec(Map<String, dynamic> lm) {
  return Vec3(
    (lm["x"] as num).toDouble(),
    (lm["y"] as num).toDouble(),
    (lm["z"] as num).toDouble(),
  );
}

// ================= PLANE =================

enum BodyPlane { frontal, sagittal }

BodyPlane detectPlane(List<Map<String, dynamic>> lm) {
  final l = toVec(lm[11]);
  final r = toVec(lm[12]);

  final dx = (l.x - r.x).abs();
  final dz = (l.z - r.z).abs();

  return dx > dz ? BodyPlane.frontal : BodyPlane.sagittal;
}

// ================= STATE =================

class _State {
  static BodyPlane? lockedPlane;
  static final Map<String, double> prevAngles = {};
  static final Map<String, bool> use2D = {};
}

// ================= PLANE NORMAL =================

Vec3 getPlaneNormal(List<Map<String, dynamic>> lm, BodyPlane plane) {
  final lShoulder = toVec(lm[11]);
  final rShoulder = toVec(lm[12]);
  final lHip = toVec(lm[23]);

  final shoulderVec = rShoulder - lShoulder;
  final hipVec = lHip - lShoulder;

  final torsoNormal = normalize(cross(shoulderVec, hipVec));

  if (plane == BodyPlane.frontal) return torsoNormal;

  return normalize(cross(torsoNormal, Vec3(0, 1, 0)));
}

// ================= PROJECTION =================

Vec3 projectOntoPlane(Vec3 v, Vec3 normal) {
  final n = normalize(normal);
  final projection = dot(v, n);

  return Vec3(
    v.x - projection * n.x,
    v.y - projection * n.y,
    v.z - projection * n.z,
  );
}

// ================= ANGLES =================

double angleOnPlane(Vec3 a, Vec3 b, Vec3 normal) {
  final aProj = projectOntoPlane(a, normal);
  final bProj = projectOntoPlane(b, normal);

  final d = dot(aProj, bProj).clamp(-1.0, 1.0);
  final c = cross(aProj, bProj);

  return atan2(magnitude(c), d) * (180 / pi);
}

double angle2D(Vec3 a, Vec3 b) {
  final dotVal = a.x * b.x + a.y * b.y;
  final mag =
      sqrt(a.x * a.x + a.y * a.y) * sqrt(b.x * b.x + b.y * b.y);

  if (mag == 0) return 0;

  return acos((dotVal / mag).clamp(-1.0, 1.0)) * (180 / pi);
}

// ================= SAFE ANGLE (HYSTERESIS) =================

double safeAngle(String key, Vec3 v1, Vec3 v2, Vec3 normal) {
  final angle3D = angleOnPlane(v1, v2, normal);
  final angle2d = angle2D(v1, v2);

  final use2D = _State.use2D[key] ?? false;

  // ENTER 2D mode
  if (!use2D && (angle3D > 170 || angle3D < 10)) {
    _State.use2D[key] = true;
    return angle2d;
  }

  // EXIT 2D mode
  if (use2D && (angle3D < 150 && angle3D > 30)) {
    _State.use2D[key] = false;
    return angle3D;
  }

  return use2D ? angle2d : angle3D;
}

// ================= PURE 3D (for knees/elbows) =================

double pure3DAngle(Vec3 v1, Vec3 v2) {
  final d = dot(v1, v2);
  final mag = magnitude(v1) * magnitude(v2);

  if (mag == 0) return 0;

  return acos((d / mag).clamp(-1.0, 1.0)) * (180 / pi);
}

// ================= SMOOTHING =================

double smooth(String key, double value) {
  final prev = _State.prevAngles[key] ?? value;

  final smoothed = 0.8 * prev + 0.2 * value;

  _State.prevAngles[key] = smoothed;
  return smoothed;
}

// ================= DEADZONE =================

double stabilize(String key, double value) {
  final prev = _State.prevAngles[key] ?? value;

  if ((value - prev).abs() < 2) return prev;

  return value;
}

// ================= MAIN =================

class PoseAngleUtils {
  static Map<String, double> calculateAllAngles(
      List<Map<String, dynamic>> lm) {
    if (lm.length < 33) return {};

    Vec3 p(int i) => toVec(lm[i]);

    // 🔥 LOCK PLANE
    _State.lockedPlane ??= detectPlane(lm);
    final plane = _State.lockedPlane!;

    final normal = getPlaneNormal(lm, plane);

    double joint(String key, int a, int b, int c) {
      final v1 = p(a) - p(b);
      final v2 = p(c) - p(b);

      final angle = safeAngle(key, v1, v2, normal);
      final stable = stabilize(key, angle);
      return smooth(key, stable);
    }

    double knee(String key, int a, int b, int c) {
      final v1 = p(a) - p(b);
      final v2 = p(c) - p(b);

      final angle = pure3DAngle(v1, v2);
      final stable = stabilize(key, angle);
      return smooth(key, stable);
    }

    return {
      "leftElbow": smooth("leftElbow",
          pure3DAngle(p(11) - p(13), p(15) - p(13))),
      "rightElbow": smooth("rightElbow",
          pure3DAngle(p(12) - p(14), p(16) - p(14))),

      "leftShoulder": joint("leftShoulder", 13, 11, 23),
      "rightShoulder": joint("rightShoulder", 14, 12, 24),

      "leftHip": joint("leftHip", 11, 23, 25),
      "rightHip": joint("rightHip", 12, 24, 26),

      // 🔥 FIXED KNEES (PURE 3D)
      "leftKnee": knee("leftKnee", 23, 25, 27),
      "rightKnee": knee("rightKnee", 24, 26, 28),

      "leftAnkle": joint("leftAnkle", 25, 27, 31),
      "rightAnkle": joint("rightAnkle", 26, 28, 32),
    };
  }

  static void reset() {
    _State.lockedPlane = null;
    _State.prevAngles.clear();
    _State.use2D.clear();
  }
}