package com.example.nereus_abp_app

import android.graphics.Bitmap
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult

class MainActivity : FlutterActivity() {

    private val CHANNEL = "nereus/pose_detection"
    private val TAG = "PoseNative"

    private var poseLandmarker: PoseLandmarker? = null
    private var latestResult: PoseLandmarkerResult? = null

    private lateinit var yuvConverter: FastYuvToRgbConverter
    private var rgbBitmap: Bitmap? = null

    // 🔥 Person tracking state
    private var lastCenter: Pair<Float, Float>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d(TAG, "configureFlutterEngine called")

        yuvConverter = FastYuvToRgbConverter(this)
        setupPoseLandmarker()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                if (call.method != "detectPoseStream") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val timestamp = call.argument<Long>("timestamp") ?: System.currentTimeMillis()

                val yBytes = call.argument<ByteArray>("plane0")
                val uBytes = call.argument<ByteArray>("plane1")
                val vBytes = call.argument<ByteArray>("plane2")

                val stride0 = call.argument<Int>("stride0") ?: 0
                val stride1 = call.argument<Int>("stride1") ?: 0
                val stride2 = call.argument<Int>("stride2") ?: 0

                val pixelStride1 = call.argument<Int>("pixelStride1") ?: 1
                val pixelStride2 = call.argument<Int>("pixelStride2") ?: 1

                if (width <= 0 || height <= 0) {
                    result.error("INVALID_SIZE", "Invalid frame size: ${width}x$height", null)
                    return@setMethodCallHandler
                }

                if (yBytes == null || uBytes == null || vBytes == null) {
                    result.error("NO_PLANES", "Missing YUV planes", null)
                    return@setMethodCallHandler
                }

                try {
                    // Create bitmap if needed
                    if (rgbBitmap == null ||
                        rgbBitmap!!.width != width ||
                        rgbBitmap!!.height != height
                    ) {
                        rgbBitmap = Bitmap.createBitmap(
                            width,
                            height,
                            Bitmap.Config.ARGB_8888
                        )
                    }

                    // Convert YUV → RGB
                    yuvConverter.yuv420ToBitmap(
                        yBytes,
                        uBytes,
                        vBytes,
                        width,
                        height,
                        stride0,
                        stride1,
                        stride2,
                        pixelStride1,
                        pixelStride2,
                        rgbBitmap!!
                    )

                    val mpImage = BitmapImageBuilder(rgbBitmap!!).build()

                    // 🔥 Async detection (FAST)
                    poseLandmarker?.detectAsync(mpImage, timestamp)

                    val detectionResult = latestResult
                    val output = mutableListOf<Map<String, Any>>()

                    if (detectionResult != null &&
                        detectionResult.landmarks().isNotEmpty()
                    ) {
                        val pose = detectionResult.landmarks()[0]

                        // 🔥 Compute stable torso center
                        val centerX =
                            (pose[11].x() + pose[12].x() + pose[23].x() + pose[24].x()) / 4f
                        val centerY =
                            (pose[11].y() + pose[12].y() + pose[23].y() + pose[24].y()) / 4f

                        val center = Pair(centerX, centerY)

                        // 🔥 Identity lock check
                        if (!isSamePerson(center)) {
                            Log.d(TAG, "Ignoring frame: different person detected")
                            result.success(emptyList<Map<String, Any>>())
                            return@setMethodCallHandler
                        }

                        // 🔥 Update tracked center
                        lastCenter = center

                        for (lm in pose) {
                            output.add(
                                mapOf(
                                    "x" to lm.x(),
                                    "y" to lm.y(),
                                    "z" to lm.z(),
                                    "visibility" to lm.visibility().orElse(0f)
                                )
                            )
                        }
                    } else {
                        // 🔥 Reset tracking if lost
                        lastCenter = null
                    }

                    result.success(output)

                } catch (e: Exception) {
                    Log.e(TAG, "Pose error", e)
                    result.error("POSE_ERROR", e.message, null)
                }
            }
    }

    private fun setupPoseLandmarker() {
        if (poseLandmarker != null) return

        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("pose_landmarker.task")
            .build()

        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumPoses(1)
            .setMinPoseDetectionConfidence(0.6f)
            .setMinTrackingConfidence(0.6f)
            .setMinPosePresenceConfidence(0.6f)
            .setResultListener { result: PoseLandmarkerResult, _ ->
                latestResult = result
            }
            .setErrorListener { e: RuntimeException ->
                Log.e(TAG, "MediaPipe error", e)
            }
            .build()

        poseLandmarker = PoseLandmarker.createFromOptions(this, options)
        Log.d(TAG, "PoseLandmarker initialized")
    }

    // 🔥 Lightweight identity lock
    private fun isSamePerson(newCenter: Pair<Float, Float>): Boolean {
        val prev = lastCenter ?: return true

        val dx = kotlin.math.abs(newCenter.first - prev.first)
        val dy = kotlin.math.abs(newCenter.second - prev.second)

        return dx < 0.15f && dy < 0.15f
    }

    override fun onDestroy() {
        super.onDestroy()

        if (::yuvConverter.isInitialized) {
            yuvConverter.release()
        }

        poseLandmarker?.close()
        poseLandmarker = null
    }
}