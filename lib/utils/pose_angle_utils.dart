import 'dart:math';

// =============================================================================
// CAMERA VIEW MODE
// =============================================================================

// =============================================================================
// ANGLE CONVENTIONS
// =============================================================================
//
//  ELBOW / KNEE  (hinge)
//    180° = fully extended / straight
//    0°   = fully flexed
//
//  FRONT CAMERA (coronal plane)
//    SHOULDER ABDUCTION
//      0°   = arm hanging straight down
//      90°  = arm out to side (T-pose)
//      180° = arm straight overhead
//
//    HIP ABDUCTION
//      0°   = leg hanging straight down (standing neutral)
//      +90° = leg straight out sideways
//
//  SIDE CAMERA (sagittal plane)
//    SHOULDER FLEXION
//      0°   = arm hanging straight down
//      +90° = arm pointing straight forward
//      -90° = arm pointing straight backward
//
//    HIP FLEXION
//      0°   = leg hanging straight down (standing neutral)
//      +90° = leg raised straight forward
//      -90° = leg kicked straight backward
//
// IMPORTANT:
// A single "shoulder" or "hip" angle cannot represent both the front-camera
// and side-camera conventions at the same time. This file returns both the
// front-plane and side-plane values, and also lets you choose which one should
// populate the primary "leftShoulder/rightShoulder" and "leftHip/rightHip"
// keys using [CameraView].
// =============================================================================

enum CameraView { front, side }

// ─────────────────────────────────────────────────────────────────────────────
// VEC3
// ─────────────────────────────────────────────────────────────────────────────

class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double get magnitude => sqrt(x * x + y * y + z * z);

  Vec3 get normalized {
    final m = magnitude;
    return m < 1e-9 ? const Vec3(0, 0, 0) : Vec3(x / m, y / m, z / m);
  }
}

double dot(Vec3 a, Vec3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

Vec3 cross(Vec3 a, Vec3 b) => Vec3(
      a.y * b.z - a.z * b.y,
      a.z * b.x - a.x * b.z,
      a.x * b.y - a.y * b.x,
    );

/// Unsigned angle between two vectors, 0–180°
double angleBetween(Vec3 a, Vec3 b) {
  final denom = a.magnitude * b.magnitude;
  if (denom < 1e-9) return 0;
  return acos((dot(a, b) / denom).clamp(-1.0, 1.0)) * (180 / pi);
}

/// Signed angle from [from] to [to], measured around [axis] (right-hand rule).
/// Returns -180° to +180°.
double signedAngle(Vec3 from, Vec3 to, Vec3 axis) {
  final unsigned = angleBetween(from, to);
  final c = cross(from, to);
  final sign = dot(c, axis) < 0 ? -1.0 : 1.0;
  return sign * unsigned;
}

/// Remove the component of [v] along [normal], returning the in-plane part.
Vec3 projectOntoPlane(Vec3 v, Vec3 normal) {
  final n = normal.normalized;
  return v - n * dot(v, n);
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Vec3 toVec(Map<String, dynamic> lm) => Vec3(
      (lm["x"] as num).toDouble(),
      (lm["y"] as num).toDouble(),
      (lm["z"] as num).toDouble(),
    );

Vec3 midpoint(Vec3 a, Vec3 b) => (a + b) * 0.5;

// ─────────────────────────────────────────────────────────────────────────────
// TORSO FRAME
// ─────────────────────────────────────────────────────────────────────────────
//
//  right   → from left shoulder to right shoulder
//  up      → from hip midpoint to shoulder midpoint (superior)
//  forward → right × up
//
// MediaPipe note: Y increases downward. We build our own anatomical frame from
// the landmark positions instead of trusting camera axes directly.

class TorsoFrame {
  final Vec3 forward; // chest direction
  final Vec3 up;      // head direction
  final Vec3 right;   // body's right side

  const TorsoFrame(this.forward, this.up, this.right);
}

TorsoFrame _buildFrame(List<Map<String, dynamic>> lm) {
  final ls = toVec(lm[11]); // left shoulder
  final rs = toVec(lm[12]); // right shoulder
  final lh = toVec(lm[23]); // left hip
  final rh = toVec(lm[24]); // right hip

  final shoulderMid = midpoint(ls, rs);
  final hipMid = midpoint(lh, rh);

  final right = (rs - ls).normalized;
  final up = (shoulderMid - hipMid).normalized;
  final forwardRaw = cross(right, up).normalized;

  // Ensure forward points "out of chest"
  final spine = (shoulderMid - hipMid).normalized;

  Vec3 forward = forwardRaw;

  // If forward is pointing backwards, flip it
  if (dot(forward, spine) < 0) {
    forward = -forward;
  }

  return TorsoFrame(forward, up, right);
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE  (smoothing)
// ─────────────────────────────────────────────────────────────────────────────

class _State {
  static TorsoFrame? prevFrame;
  static final Map<String, double> prevSmooth = {};
}

TorsoFrame _smoothFrame(TorsoFrame cur) {
  final prev = _State.prevFrame;
  if (prev == null) {
    _State.prevFrame = cur;
    return cur;
  }

  Vec3 lerp(Vec3 a, Vec3 b) => Vec3(
        0.8 * a.x + 0.2 * b.x,
        0.8 * a.y + 0.2 * b.y,
        0.8 * a.z + 0.2 * b.z,
      ).normalized;

  final forward = lerp(prev.forward, cur.forward);
  final up = lerp(prev.up, cur.up);

  // Keep the frame orthogonal. Since forward = right × up, we recover
  // right = up × forward (not forward × up).
  final rightFinal = cross(up, forward).normalized;

  _State.prevFrame = TorsoFrame(forward, up, rightFinal);
  return _State.prevFrame!;
}

double _smooth(String key, double value, {double alpha = 0.35}) {
  final prev = _State.prevSmooth[key] ?? value;
  final s = (1 - alpha) * prev + alpha * value;
  _State.prevSmooth[key] = s;
  return s;
}

// ─────────────────────────────────────────────────────────────────────────────
// JOINT CALCULATIONS
// ─────────────────────────────────────────────────────────────────────────────

/// Hinge angle at [joint] between segments [proximal]→[joint] and
/// [joint]→[distal].
/// 180° = straight, 0° = fully flexed.
double _hingeAngle(Vec3 proximal, Vec3 joint, Vec3 distal) {
  final v1 = (proximal - joint).normalized;
  final v2 = (distal - joint).normalized;
  return angleBetween(v1, v2);
}

/// FRONT CAMERA: Shoulder abduction in the coronal plane.
/// 0 = down, 90 = T-pose, 180 = overhead.
double _shoulderAbduction(Vec3 armVec, TorsoFrame f) {
  final inPlane = projectOntoPlane(armVec, f.forward);
  final down = -f.up;
  return angleBetween(down, inPlane);
}

/// SIDE CAMERA: Shoulder flexion in the sagittal plane.
/// 0 = down, +90 = forward, -90 = backward.
double _shoulderFlexion(Vec3 armVec, TorsoFrame f) {
  final inPlane = projectOntoPlane(armVec, f.right);
  final down = -f.up;
  return signedAngle(down, inPlane, -f.right);
}

/// FRONT CAMERA: Hip abduction in the coronal plane.
/// 0 = neutral, ~90 = full side split.
double _hipAbduction(Vec3 thighVec, TorsoFrame f) {
  final inPlane = projectOntoPlane(thighVec, f.forward);
  final down = -f.up;
  return angleBetween(down, inPlane);
}

/// SIDE CAMERA: Hip flexion in the sagittal plane.
/// 0 = neutral, +90 = forward, -90 = backward.
double _hipFlexion(Vec3 thighVec, TorsoFrame f) {
  final inPlane = projectOntoPlane(thighVec, f.right);
  final down = -f.up;
  return signedAngle(down, inPlane, f.right);
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC API
// ─────────────────────────────────────────────────────────────────────────────

class PoseAngleUtils {
  /// Returns a map of joint angles from MediaPipe Pose landmarks (33 points).
  ///
  /// Primary keys depend on [view]:
  ///   front -> shoulder/hip abduction
  ///   side  -> shoulder/hip flexion
  ///
  /// Extra keys are always returned:
  ///   leftShoulderAbduct / rightShoulderAbduct
  ///   leftShoulderFlex   / rightShoulderFlex
  ///   leftHipAbduct      / rightHipAbduct
  ///   leftHipFlex        / rightHipFlex
  static Map<String, double> calculateAllAngles(
    List<Map<String, dynamic>> lm, {
    CameraView view = CameraView.front,
  }) {
    if (lm.length < 33) return {};

    Vec3 p(int i) => toVec(lm[i]);

    final frame = _smoothFrame(_buildFrame(lm));
    final viewKey = view == CameraView.front ? 'front' : 'side';

    // Arm vectors (shoulder → elbow)
    final lArm = p(13) - p(11);
    final rArm = p(14) - p(12);

    // Thigh vectors (hip → knee)
    final lThigh = p(25) - p(23);
    final rThigh = p(26) - p(24);

    final lShoulderAbd = _shoulderAbduction(lArm, frame);
    final rShoulderAbd = _shoulderAbduction(rArm, frame);
    final lShoulderFlex = _shoulderFlexion(lArm, frame);
    final rShoulderFlex = _shoulderFlexion(rArm, frame);

    final lHipAbd = _hipAbduction(lThigh, frame);
    final rHipAbd = _hipAbduction(rThigh, frame);
    final lHipFlex = _hipFlexion(lThigh, frame);
    final rHipFlex = _hipFlexion(rThigh, frame);

    return {
      // Hinges
      'leftElbow': _smooth('lElbow', _hingeAngle(p(11), p(13), p(15)), alpha: 0.6),
      'rightElbow': _smooth('rElbow', _hingeAngle(p(12), p(14), p(16)), alpha: 0.6),
      'leftKnee': _smooth('lKnee', _hingeAngle(p(23), p(25), p(27)), alpha: 0.6),
      'rightKnee': _smooth('rKnee', _hingeAngle(p(24), p(26), p(28)), alpha: 0.6),

      // Primary display values - choose based on camera view
      'leftShoulder': _smooth(
        'lShoulder_$viewKey',
        view == CameraView.front ? lShoulderAbd : lShoulderFlex,
      ),
      'rightShoulder': _smooth(
        'rShoulder_$viewKey',
        view == CameraView.front ? rShoulderAbd : rShoulderFlex,
      ),
      'leftHip': _smooth(
        'lHip_$viewKey',
        view == CameraView.front ? lHipAbd : lHipFlex,
      ),
      'rightHip': _smooth(
        'rHip_$viewKey',
        view == CameraView.front ? rHipAbd : rHipFlex,
      ),

      // Always-available breakdown values
      'leftShoulderAbduct': _smooth('lSAbd', lShoulderAbd),
      'rightShoulderAbduct': _smooth('rSAbd', rShoulderAbd),
      'leftShoulderFlex': _smooth('lSFlex', lShoulderFlex),
      'rightShoulderFlex': _smooth('rSFlex', rShoulderFlex),

      'leftHipAbduct': _smooth('lHAbd', lHipAbd),
      'rightHipAbduct': _smooth('rHAbd', rHipAbd),
      'leftHipFlex': _smooth('lHFlex', lHipFlex),
      'rightHipFlex': _smooth('rHFlex', rHipFlex),

      'leftAnkle': _smooth('lAnkle', _hingeAngle(p(25), p(27), p(31)), alpha: 0.6),
      'rightAnkle': _smooth('rAnkle', _hingeAngle(p(26), p(28), p(32)), alpha: 0.6),
    };
  }

  static void reset() {
    _State.prevFrame = null;
    _State.prevSmooth.clear();
  }
}
