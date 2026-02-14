package com.example.nereus_abp_app

import android.graphics.Bitmap
import android.graphics.Matrix
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
    private var rotatedBitmap: Bitmap? = null

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
                val rotation = call.argument<Int>("rotation") ?: 0
                val timestamp = call.argument<Long>("timestamp") ?: 0L

                val yBytes = call.argument<ByteArray>("plane0")
                val uBytes = call.argument<ByteArray>("plane1")
                val vBytes = call.argument<ByteArray>("plane2")

                val stride0 = call.argument<Int>("stride0") ?: 0
                val stride1 = call.argument<Int>("stride1") ?: 0
                val stride2 = call.argument<Int>("stride2") ?: 0

                val pixelStride1 = call.argument<Int>("pixelStride1") ?: 1
                val pixelStride2 = call.argument<Int>("pixelStride2") ?: 1

                if (yBytes == null || uBytes == null || vBytes == null) {
                    result.error("NO_PLANES", "Missing YUV planes", null)
                    return@setMethodCallHandler
                }

                try {
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
                    poseLandmarker?.detectAsync(mpImage, timestamp)

                    val detectionResult = latestResult
                    val output = mutableListOf<Map<String, Any>>()

                    if (detectionResult != null &&
                        detectionResult.landmarks().isNotEmpty()
                    ) {
                        val pose = detectionResult.landmarks()[0]
                        for (lm in pose) {
                            output.add(
                                mapOf(
                                    "x" to lm.x(),
                                    "y" to lm.y(),
                                    "z" to lm.z()
                                )
                            )
                        }
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
            .setMinPoseDetectionConfidence(0.5f)
            .setMinPosePresenceConfidence(0.5f)
            .setResultListener { result: PoseLandmarkerResult, _: com.google.mediapipe.framework.image.MPImage ->
                latestResult = result
                Log.d(TAG, "Result listener fired. Poses=${result.landmarks().size}")
            }
            .setErrorListener { e: RuntimeException ->
                Log.e(TAG, "MediaPipe error", e)
            }
            .build()

        poseLandmarker = PoseLandmarker.createFromOptions(this, options)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::yuvConverter.isInitialized) {
            yuvConverter.release()
        }
        poseLandmarker?.close()
    }
}
