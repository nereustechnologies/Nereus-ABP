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
      let p1PixelStride = (args["pixelStride1"] as? Int) ?? 1

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
      let p2PixelStride = (args["pixelStride2"] as? Int) ?? 1

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
            vStride: p2Stride,
            uPixelStride: p1PixelStride,
            vPixelStride: p2PixelStride
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

  // MARK: - YUV/NV12 buffers

  private func createNV12PixelBufferFromYUV420(
    y: Data,
    u: Data,
    v: Data,
    width: Int,
    height: Int,
    yStride: Int,
    uStride: Int,
    vStride: Int,
    uPixelStride: Int,
    vPixelStride: Int
  ) throws -> CVPixelBuffer {
    let buffer = try createEmptyNV12PixelBuffer(width: width, height: height)
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    try copyLumaPlane(y, to: buffer, width: width, height: height, sourceStride: yStride)
    try interleaveChromaPlanes(
      u: u,
      v: v,
      to: buffer,
      width: width,
      height: height,
      uStride: uStride,
      vStride: vStride,
      uPixelStride: max(uPixelStride, 1),
      vPixelStride: max(vPixelStride, 1)
    )

    return buffer
  }

  private func createNV12PixelBufferfromYUV420(
    y: Data,
    u: Data,
    v: Data,
    width: Int,
    height: Int,
    yStride: Int,
    uStride: Int,
    vStride: Int,
    uPixelStride: Int,
    vPixelStride: Int
  ) throws -> CVPixelBuffer {
    try createNV12PixelBufferFromYUV420(
      y: y,
      u: u,
      v: v,
      width: width,
      height: height,
      yStride: yStride,
      uStride: uStride,
      vStride: vStride,
      uPixelStride: uPixelStride,
      vPixelStride: vPixelStride
    )
  }

  private func createNV12PixelBufferFromNV12Planes(
    y: Data,
    uv: Data,
    width: Int,
    height: Int,
    yStride: Int,
    uvStride: Int
  ) throws -> CVPixelBuffer {
    let buffer = try createEmptyNV12PixelBuffer(width: width, height: height)
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    try copyLumaPlane(y, to: buffer, width: width, height: height, sourceStride: yStride)

    guard let dstUVBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) else {
      throw NSError(domain: "PixelBufferError", code: -2, userInfo: [
        NSLocalizedDescriptionKey: "Unable to access destination UV plane"
      ])
    }

    let chromaHeight = height / 2
    let chromaBytesPerRow = width
    let dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)

    try uv.withUnsafeBytes { uvBytes in
      guard let srcUVBase = uvBytes.baseAddress else {
        throw NSError(domain: "PixelBufferError", code: -3, userInfo: [
          NSLocalizedDescriptionKey: "Unable to access source UV plane"
        ])
      }

      for row in 0..<chromaHeight {
        let srcOffset = row * uvStride
        let dstOffset = row * dstUVStride

        guard srcOffset + chromaBytesPerRow <= uv.count else {
          throw NSError(domain: "PixelBufferError", code: -4, userInfo: [
            NSLocalizedDescriptionKey: "UV plane is smaller than expected"
          ])
        }

        memcpy(dstUVBase.advanced(by: dstOffset), srcUVBase.advanced(by: srcOffset), chromaBytesPerRow)
      }
    }

    return buffer
  }

  private func createEmptyNV12PixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let attrs: CFDictionary = [
      kCVPixelBufferIOSurfacePropertiesKey as String: [:],
      kCVPixelBufferMetalCompatibilityKey as String: true,
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ] as CFDictionary

    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
      attrs,
      &buffer
    )

    guard status == kCVReturnSuccess, let pixelBuffer = buffer else {
      throw NSError(domain: "PixelBufferError", code: Int(status), userInfo: [
        NSLocalizedDescriptionKey: "Unable to create NV12 pixel buffer"
      ])
    }

    return pixelBuffer
  }

  private func copyLumaPlane(
    _ y: Data,
    to buffer: CVPixelBuffer,
    width: Int,
    height: Int,
    sourceStride: Int
  ) throws {
    guard let dstYBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else {
      throw NSError(domain: "PixelBufferError", code: -5, userInfo: [
        NSLocalizedDescriptionKey: "Unable to access destination Y plane"
      ])
    }

    let dstYStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)

    try y.withUnsafeBytes { yBytes in
      guard let srcYBase = yBytes.baseAddress else {
        throw NSError(domain: "PixelBufferError", code: -6, userInfo: [
          NSLocalizedDescriptionKey: "Unable to access source Y plane"
        ])
      }

      for row in 0..<height {
        let srcOffset = row * sourceStride
        let dstOffset = row * dstYStride

        guard srcOffset + width <= y.count else {
          throw NSError(domain: "PixelBufferError", code: -7, userInfo: [
            NSLocalizedDescriptionKey: "Y plane is smaller than expected"
          ])
        }

        memcpy(dstYBase.advanced(by: dstOffset), srcYBase.advanced(by: srcOffset), width)
      }
    }
  }

  private func interleaveChromaPlanes(
    u: Data,
    v: Data,
    to buffer: CVPixelBuffer,
    width: Int,
    height: Int,
    uStride: Int,
    vStride: Int,
    uPixelStride: Int,
    vPixelStride: Int
  ) throws {
    guard let dstUVBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) else {
      throw NSError(domain: "PixelBufferError", code: -8, userInfo: [
        NSLocalizedDescriptionKey: "Unable to access destination UV plane"
      ])
    }

    let chromaWidth = width / 2
    let chromaHeight = height / 2
    let dstUVStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)

    try u.withUnsafeBytes { uBytes in
      try v.withUnsafeBytes { vBytes in
        guard let srcUBase = uBytes.baseAddress,
              let srcVBase = vBytes.baseAddress else {
          throw NSError(domain: "PixelBufferError", code: -9, userInfo: [
            NSLocalizedDescriptionKey: "Unable to access source chroma planes"
          ])
        }

        for row in 0..<chromaHeight {
          for col in 0..<chromaWidth {
            let uOffset = row * uStride + col * uPixelStride
            let vOffset = row * vStride + col * vPixelStride
            let dstOffset = row * dstUVStride + col * 2

            guard uOffset < u.count, vOffset < v.count else {
              throw NSError(domain: "PixelBufferError", code: -10, userInfo: [
                NSLocalizedDescriptionKey: "Chroma plane is smaller than expected"
              ])
            }

            dstUVBase.storeBytes(
              of: srcUBase.load(fromByteOffset: uOffset, as: UInt8.self),
              toByteOffset: dstOffset,
              as: UInt8.self
            )
            dstUVBase.storeBytes(
              of: srcVBase.load(fromByteOffset: vOffset, as: UInt8.self),
              toByteOffset: dstOffset + 1,
              as: UInt8.self
            )
          }
        }
      }
    }
  }

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
