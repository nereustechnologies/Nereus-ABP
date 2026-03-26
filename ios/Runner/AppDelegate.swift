import UIKit
import Flutter
import MediaPipeTasksVision
import AVFoundation
import CoreImage

@main
@objc class AppDelegate: FlutterAppDelegate, PoseLandmarkerLiveStreamDelegate {

  private let CHANNEL = "nereus/pose_detection"

  private var poseLandmarker: PoseLandmarker?
  private var latestResult: PoseLandmarkerResult?

  // 🔥 Lightweight person tracking
  private var lastCenter: CGPoint?

  private let ciContext = CIContext(options: nil)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let channel = FlutterMethodChannel(
      name: CHANNEL,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }

      guard call.method == "detectPoseStream",
            let args = call.arguments as? [String: Any]
      else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let width = args["width"] as? Int,
            let height = args["height"] as? Int,
            let yPlane = args["plane0"] as? FlutterStandardTypedData,
            let plane1 = args["plane1"] as? FlutterStandardTypedData
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil))
        return
      }

      let yStride = (args["stride0"] as? Int) ?? width
      let p1Stride = (args["stride1"] as? Int) ?? width

      let timestampMs: Int
      if let t64 = args["timestamp"] as? Int64 {
        timestampMs = Int(clamping: t64)
      } else if let t = args["timestamp"] as? Int {
        timestampMs = t
      } else {
        timestampMs = Int(Date().timeIntervalSince1970 * 1000)
      }

      let plane2 = args["plane2"] as? FlutterStandardTypedData
      let p2Stride = (args["stride2"] as? Int) ?? (width / 2)

      do {
        if self.poseLandmarker == nil {
          self.setupPoseLandmarker()
        }

        // 🔥 Build NV12 buffer
        let nv12Buffer: CVPixelBuffer
        if let vPlane = plane2 {
          nv12Buffer = try self.createNV12PixelBufferFromYUV420(
            y: yPlane.data,
            u: plane1.data,
            v: vPlane.data,
            width: width,
            height: height,
            yStride: yStride,
            uStride: p1Stride,
            vStride: p2Stride
          )
        } else {
          nv12Buffer = try self.createNV12PixelBufferFromNV12Planes(
            y: yPlane.data,
            uv: plane1.data,
            width: width,
            height: height,
            yStride: yStride,
            uvStride: p1Stride
          )
        }

        // 🔥 Convert to BGRA
        let bgraBuffer = try self.convertNV12ToBGRA(nv12Buffer)

        let mpImage = try MPImage(pixelBuffer: bgraBuffer)

        // 🔥 Async detection (FAST)
        try self.poseLandmarker?.detectAsync(
          image: mpImage,
          timestampInMilliseconds: timestampMs
        )

        // 🔥 Use cached result
        var output: [[String: Any]] = []

        if let pose = self.latestResult?.landmarks.first {

          // 🔥 Torso-based center (stable)
          let centerX = (pose[11].x + pose[12].x + pose[23].x + pose[24].x) / 4.0
          let centerY = (pose[11].y + pose[12].y + pose[23].y + pose[24].y) / 4.0

          let center = CGPoint(x: centerX, y: centerY)

          // 🔥 Identity lock
          if !self.isSamePerson(center) {
            result([])
            return
          }

          self.lastCenter = center

          for lm in pose {
            output.append([
              "x": lm.x,
              "y": lm.y,
              "z": lm.z,
              "visibility": lm.visibility ?? 0.0
            ])
          }

        } else {
          self.lastCenter = nil
        }

        result(output)

      } catch {
        result(FlutterError(code: "POSE_ERROR", message: error.localizedDescription, details: nil))
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - MediaPipe setup

  private func setupPoseLandmarker() {
    guard poseLandmarker == nil else { return }

    guard let modelPath = Bundle.main.path(forResource: "pose_landmarker", ofType: "task") else {
      fatalError("pose_landmarker.task not found")
    }

    let baseOptions = BaseOptions()
    baseOptions.modelAssetPath = modelPath

    var options = PoseLandmarkerOptions()
    options.baseOptions = baseOptions
    options.runningMode = .liveStream
    options.numPoses = 1
    options.minPoseDetectionConfidence = 0.6
    options.minPosePresenceConfidence = 0.6
    options.minTrackingConfidence = 0.6
    options.poseLandmarkerLiveStreamDelegate = self

    do {
      poseLandmarker = try PoseLandmarker(options: options)
    } catch {
      fatalError("Failed to create PoseLandmarker: \(error)")
    }
  }

  // MARK: - Delegate

  func poseLandmarker(
    _ poseLandmarker: PoseLandmarker,
    didFinishDetection result: PoseLandmarkerResult?,
    timestampInMilliseconds: Int,
    error: Error?
  ) {
    if let r = result {
      self.latestResult = r
    }
  }

  // MARK: - Lightweight tracking

  private func isSamePerson(_ newCenter: CGPoint) -> Bool {
    guard let prev = lastCenter else { return true }

    let dx = abs(newCenter.x - prev.x)
    let dy = abs(newCenter.y - prev.y)

    return dx < 0.15 && dy < 0.15
  }

  // MARK: - NV12 → BGRA

  private func convertNV12ToBGRA(_ src: CVPixelBuffer) throws -> CVPixelBuffer {
    let width = CVPixelBufferGetWidth(src)
    let height = CVPixelBufferGetHeight(src)

    var dst: CVPixelBuffer?

    let attrs: CFDictionary = [
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ] as CFDictionary

    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      attrs,
      &dst
    )

    guard status == kCVReturnSuccess, let dstBuffer = dst else {
      throw NSError(domain: "PixelBufferError", code: Int(status))
    }

    let ciImage = CIImage(cvPixelBuffer: src)

    CVPixelBufferLockBaseAddress(dstBuffer, [])
    ciContext.render(ciImage, to: dstBuffer)
    CVPixelBufferUnlockBaseAddress(dstBuffer, [])

    return dstBuffer
  }
}