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

  // MediaPipe MPImage(pixelBuffer:) in some SDK builds only supports BGRA.
  private let ciContext = CIContext(options: nil)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // GeneratedPluginRegistrant is exposed via Runner-Bridging-Header.h
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let channel = FlutterMethodChannel(
      name: CHANNEL,
      binaryMessenger: controller.binaryMessenger
    )

    // IMPORTANT: Do not init MediaPipe at app launch (can stall/white screen).
    // We'll init lazily on first call.

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }

      guard call.method == "detectPoseStream",
            let args = call.arguments as? [String: Any]
      else {
        result(FlutterMethodNotImplemented)
        return
      }

      // Required (works for iOS + Android)
      guard let width = args["width"] as? Int,
            let height = args["height"] as? Int,
            let yPlane = args["plane0"] as? FlutterStandardTypedData,
            let plane1 = args["plane1"] as? FlutterStandardTypedData
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing/invalid args", details: nil))
        return
      }

      // Strides (sent from Dart)
      let yStride = (args["stride0"] as? Int) ?? width
      let p1Stride = (args["stride1"] as? Int) ?? width

      // Timestamp can come across as Int or Int64 depending on platform
      let timestampMs: Int
      if let t64 = args["timestamp"] as? Int64 {
        timestampMs = Int(clamping: t64)
      } else if let t = args["timestamp"] as? Int {
        timestampMs = t
      } else {
        timestampMs = Int(Date().timeIntervalSince1970 * 1000)
      }

      // Optional (Android sends plane2, iOS often doesn't)
      let plane2 = args["plane2"] as? FlutterStandardTypedData
      let p2Stride = (args["stride2"] as? Int) ?? (width / 2)

      do {
        // Lazy init
        if self.poseLandmarker == nil {
          self.setupPoseLandmarker()
        }

        // Build NV12 pixel buffer first (fast + matches iOS camera)
        let nv12Buffer: CVPixelBuffer
        if let vPlane = plane2 {
          // Android-style: Y + U + V (3 planes) -> NV12 (UV interleaved)
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
          // iOS-style: plane0=Y, plane1=UV already interleaved (NV12)
          nv12Buffer = try self.createNV12PixelBufferFromNV12Planes(
            y: yPlane.data,
            uv: plane1.data,
            width: width,
            height: height,
            yStride: yStride,
            uvStride: p1Stride
          )
        }

        // MediaPipe expects BGRA in your SDK build → convert NV12 -> BGRA
        let bgraBuffer = try self.convertNV12ToBGRA(nv12Buffer)
        let mpImage = try MPImage(pixelBuffer: bgraBuffer)

        try self.poseLandmarker?.detectAsync(
          image: mpImage,
          timestampInMilliseconds: timestampMs
        )

        // Live stream results come asynchronously via delegate; return latest cached result.
        var output: [[String: Any]] = []
        if let pose = self.latestResult?.landmarks.first {
          for lm in pose {
            output.append([
              "x": lm.x,
              "y": lm.y,
              "z": lm.z
            ])
          }
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
      fatalError("pose_landmarker.task not found in bundle (Copy Bundle Resources + Target Membership).")
    }

    let baseOptions = BaseOptions()
    baseOptions.modelAssetPath = modelPath

    var options = PoseLandmarkerOptions()
    options.baseOptions = baseOptions
    options.runningMode = .liveStream
    options.numPoses = 1
    options.minPoseDetectionConfidence = 0.5
    options.minPosePresenceConfidence = 0.5
    options.poseLandmarkerLiveStreamDelegate = self

    do {
      poseLandmarker = try PoseLandmarker(options: options)
    } catch {
      fatalError("Failed to create PoseLandmarker: \(error)")
    }
  }

  // MARK: - PoseLandmarkerLiveStreamDelegate

  func poseLandmarker(
    _ poseLandmarker: PoseLandmarker,
    didFinishDetection result: PoseLandmarkerResult?,
    timestampInMilliseconds: Int,
    error: Error?
  ) {
    if let err = error {
      print("PoseLandmarker error: \(err)")
      return
    }
    if let r = result {
      self.latestResult = r
    }
  }

  // Kept harmlessly; not required for protocol conformance.
  func poseLandmarker(
    _ poseLandmarker: PoseLandmarker,
    didFinishDetectionWithResult result: PoseLandmarkerResult?,
    timestampInMilliseconds: Int,
    error: Error?
  ) {
    if let err = error {
      print("PoseLandmarker error (alt): \(err)")
      return
    }
    if let r = result {
      self.latestResult = r
    }
  }

  // MARK: - NV12 builders (stride-correct)

  // iOS NV12 path: plane0=Y, plane1=UV interleaved
  private func createNV12PixelBufferFromNV12Planes(
    y: Data,
    uv: Data,
    width: Int,
    height: Int,
    yStride: Int,
    uvStride: Int
  ) throws -> CVPixelBuffer {

    var pixelBuffer: CVPixelBuffer?

    let attrs: CFDictionary = [
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ] as CFDictionary

    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
      attrs,
      &pixelBuffer
    )

    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
      throw NSError(
        domain: "PixelBufferError",
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "CVPixelBufferCreate(NV12) failed: \(status)"]
      )
    }

    CVPixelBufferLockBaseAddress(buffer, [])

    // Copy Y row-by-row (handles padding/stride)
    let dstYBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
    if let dstY = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) {
      y.withUnsafeBytes { src in
        guard let srcBase = src.baseAddress else { return }
        for row in 0..<height {
          let srcRow = srcBase.advanced(by: row * yStride)
          let dstRow = dstY.advanced(by: row * dstYBytesPerRow)
          memcpy(dstRow, srcRow, width)
        }
      }
    }

    // Copy UV row-by-row (each row is width bytes in NV12)
    let uvHeight = height / 2
    let dstUVBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
    if let dstUV = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) {
      uv.withUnsafeBytes { src in
        guard let srcBase = src.baseAddress else { return }
        for row in 0..<uvHeight {
          let srcRow = srcBase.advanced(by: row * uvStride)
          let dstRow = dstUV.advanced(by: row * dstUVBytesPerRow)
          memcpy(dstRow, srcRow, width)
        }
      }
    }

    CVPixelBufferUnlockBaseAddress(buffer, [])
    return buffer
  }

  // Android YUV420 (3 planes) -> NV12 (UV interleaved)
  private func createNV12PixelBufferFromYUV420(
    y: Data,
    u: Data,
    v: Data,
    width: Int,
    height: Int,
    yStride: Int,
    uStride: Int,
    vStride: Int
  ) throws -> CVPixelBuffer {

    var pixelBuffer: CVPixelBuffer?

    let attrs: CFDictionary = [
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ] as CFDictionary

    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
      attrs,
      &pixelBuffer
    )

    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
      throw NSError(
        domain: "PixelBufferError",
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "CVPixelBufferCreate(NV12) failed: \(status)"]
      )
    }

    CVPixelBufferLockBaseAddress(buffer, [])

    // Copy Y row-by-row
    let dstYBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
    if let dstY = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) {
      y.withUnsafeBytes { src in
        guard let srcBase = src.baseAddress else { return }
        for row in 0..<height {
          let srcRow = srcBase.advanced(by: row * yStride)
          let dstRow = dstY.advanced(by: row * dstYBytesPerRow)
          memcpy(dstRow, srcRow, width)
        }
      }
    }

    // Interleave UV (NV12 expects U then V)
    let uvHeight = height / 2
    let dstUVBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
    if let dstUV = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) {
      u.withUnsafeBytes { uSrc in
        v.withUnsafeBytes { vSrc in
          guard let uBase = uSrc.baseAddress, let vBase = vSrc.baseAddress else { return }
          for row in 0..<uvHeight {
            let dstRow = dstUV.advanced(by: row * dstUVBytesPerRow)
            let uRow = uBase.advanced(by: row * uStride)
            let vRow = vBase.advanced(by: row * vStride)
            for col in 0..<(width / 2) {
              // UV order
              dstRow.storeBytes(of: uRow.load(fromByteOffset: col, as: UInt8.self),
                                toByteOffset: col * 2, as: UInt8.self)
              dstRow.storeBytes(of: vRow.load(fromByteOffset: col, as: UInt8.self),
                                toByteOffset: col * 2 + 1, as: UInt8.self)
            }
          }
        }
      }
    }

    CVPixelBufferUnlockBaseAddress(buffer, [])
    return buffer
  }

  // MARK: - NV12 -> BGRA for MediaPipe MPImage compatibility

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
      throw NSError(
        domain: "PixelBufferError",
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "CVPixelBufferCreate(BGRA) failed: \(status)"]
      )
    }

    let ciImage = CIImage(cvPixelBuffer: src)

    CVPixelBufferLockBaseAddress(dstBuffer, [])
    ciContext.render(ciImage, to: dstBuffer)
    CVPixelBufferUnlockBaseAddress(dstBuffer, [])

    return dstBuffer
  }
}
