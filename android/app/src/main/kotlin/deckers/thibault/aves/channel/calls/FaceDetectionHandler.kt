package deckers.thibault.aves.channel.calls

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import androidx.core.net.toUri
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DecodeFormat
import com.bumptech.glide.request.RequestOptions
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import deckers.thibault.aves.channel.calls.Coresult.Companion.safe
import deckers.thibault.aves.utils.LogUtils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max

class FaceDetectionHandler(private val context: Context) : MethodCallHandler {
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "detectFaces" -> ioScope.launch { safe(call, result, ::detectFaces) }
            else -> result.notImplemented()
        }
    }

    private fun detectFaces(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")?.toUri()
        val width = call.argument<Int>("width") ?: 0
        val height = call.argument<Int>("height") ?: 0

        if (uri == null) {
            result.error("detectFaces-args", "missing uri", null)
            return
        }

        var bitmap: Bitmap? = null
        var detector: FaceDetector? = null

        try {
            bitmap = loadThumbnail(uri, width, height)
            if (bitmap == null) {
                result.success(hashMapOf("faceCount" to 0))
                return
            }
            val workingBitmap = bitmap ?: return

            val image = InputImage.fromBitmap(workingBitmap, 0)
            val options = FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
                .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
                .setMinFaceSize(MIN_FACE_SIZE)
                .build()
            val faceDetector = FaceDetection.getClient(options)
            detector = faceDetector

            val faces: List<Face> = Tasks.await(faceDetector.process(image))
            val bitmapWidth = workingBitmap.width.toFloat()
            val bitmapHeight = workingBitmap.height.toFloat()

            val debugLines = mutableListOf<String>()
            debugLines.add("bitmap=${workingBitmap.width}x${workingBitmap.height}, raw=${faces.size} faces")

            val validFaces = mutableListOf<Face>()
            for ((i, face) in faces.withIndex()) {
                val bounds = face.boundingBox
                val relativeWidth = (bounds.right - bounds.left) / bitmapWidth
                val relativeHeight = (bounds.bottom - bounds.top) / bitmapHeight
                val relativeArea = relativeWidth * relativeHeight
                val yaw = face.headEulerAngleY
                val roll = face.headEulerAngleZ
                val leftEye = face.getLandmark(FaceLandmark.LEFT_EYE)
                val rightEye = face.getLandmark(FaceLandmark.RIGHT_EYE)
                val nose = face.getLandmark(FaceLandmark.NOSE_BASE)
                val hasLeftEye = leftEye != null
                val hasRightEye = rightEye != null
                val hasNose = nose != null
                val hasLeftMouth = face.getLandmark(FaceLandmark.MOUTH_LEFT) != null
                val hasRightMouth = face.getLandmark(FaceLandmark.MOUTH_RIGHT) != null

                val hasCoreLandmarks = hasLeftEye && hasRightEye && hasNose
                val isPoseAcceptable = abs(yaw) <= MAX_ABS_YAW && abs(roll) <= MAX_ABS_ROLL
                val isLargeEnough = max(relativeWidth, relativeHeight) >= MIN_RELATIVE_FACE_EXTENT && relativeArea >= MIN_RELATIVE_FACE_AREA
                val relativeEyeDistance = if (leftEye != null && rightEye != null) {
                    hypot(
                        (leftEye.position.x - rightEye.position.x).toDouble(),
                        (leftEye.position.y - rightEye.position.y).toDouble(),
                    ).toFloat() / max(bitmapWidth, bitmapHeight)
                } else {
                    0f
                }
                val hasEnoughEyeSeparation = relativeEyeDistance >= MIN_RELATIVE_EYE_DISTANCE
                val valid = hasCoreLandmarks && isPoseAcceptable && isLargeEnough && hasEnoughEyeSeparation

                debugLines.add(
                    "face[$i] size=${String.format("%.2f", relativeWidth)}x${String.format("%.2f", relativeHeight)} " +
                        "area=${String.format("%.3f", relativeArea)} eyeDist=${String.format("%.3f", relativeEyeDistance)} " +
                        "yaw=${String.format("%.1f", yaw)} roll=${String.format("%.1f", roll)} " +
                        "LE=$hasLeftEye RE=$hasRightEye nose=$hasNose LM=$hasLeftMouth RM=$hasRightMouth " +
                        "largeEnough=$isLargeEnough eyeSep=$hasEnoughEyeSeparation valid=$valid"
                )

                if (valid) {
                    validFaces.add(face)
                }
            }
            debugLines.add("validFaces=${validFaces.size}")

            val boundingBoxes = JSONArray()
            for (face in validFaces) {
                val bounds = face.boundingBox
                boundingBoxes.put(
                    JSONObject().apply {
                        put("left", (bounds.left / bitmapWidth).toDouble())
                        put("top", (bounds.top / bitmapHeight).toDouble())
                        put("right", (bounds.right / bitmapWidth).toDouble())
                        put("bottom", (bounds.bottom / bitmapHeight).toDouble())
                        put("yaw", face.headEulerAngleY.toDouble())
                        put("roll", face.headEulerAngleZ.toDouble())
                        put("landmarks", JSONObject().apply {
                            put("leftEye", face.getLandmark(FaceLandmark.LEFT_EYE).toJson(bitmapWidth, bitmapHeight))
                            put("rightEye", face.getLandmark(FaceLandmark.RIGHT_EYE).toJson(bitmapWidth, bitmapHeight))
                            put("nose", face.getLandmark(FaceLandmark.NOSE_BASE).toJson(bitmapWidth, bitmapHeight))
                            put("leftMouth", face.getLandmark(FaceLandmark.MOUTH_LEFT).toJson(bitmapWidth, bitmapHeight))
                            put("rightMouth", face.getLandmark(FaceLandmark.MOUTH_RIGHT).toJson(bitmapWidth, bitmapHeight))
                        })
                    }
                )
            }

            result.success(
                hashMapOf(
                    "faceCount" to validFaces.size,
                    "boundingBoxes" to boundingBoxes.toString(),
                    "debugInfo" to debugLines.joinToString("\n"),
                )
            )
        } catch (e: Exception) {
            result.error("detectFaces-exception", e.message, e.stackTraceToString())
        } finally {
            bitmap?.takeUnless { it.isRecycled }?.recycle()
            detector?.close()
        }
    }

    private fun loadThumbnail(uri: Uri, width: Int, height: Int): Bitmap? {
        val maxDimension = if (width > 0 && height > 0) {
            max(width, height).coerceAtMost(MAX_BITMAP_DIMENSION)
        } else {
            MAX_BITMAP_DIMENSION
        }

        val scale = if (width > 0 && height > 0) {
            maxDimension.toFloat() / max(width, height)
        } else {
            1f
        }

        val targetWidth = if (width > 0) (width * scale).toInt().coerceAtLeast(1) else maxDimension
        val targetHeight = if (height > 0) (height * scale).toInt().coerceAtLeast(1) else maxDimension

        return try {
            Glide.with(context)
                .asBitmap()
                .load(uri)
                .apply(
                    RequestOptions()
                        .format(DecodeFormat.PREFER_RGB_565)
                        .override(targetWidth, targetHeight)
                        .disallowHardwareConfig()
                )
                .submit()
                .get()
        } catch (e: Exception) {
            null
        }
    }

    private fun com.google.mlkit.vision.face.FaceLandmark?.toJson(bitmapWidth: Float, bitmapHeight: Float): JSONObject? {
        val point = this?.position ?: return null
        return JSONObject().apply {
            put("x", (point.x / bitmapWidth).toDouble())
            put("y", (point.y / bitmapHeight).toDouble())
        }
    }

    companion object {
        private val LOG_TAG = LogUtils.createTag<FaceDetectionHandler>()
        const val CHANNEL = "deckers.thibault/aves/face_detection"
        private const val MAX_BITMAP_DIMENSION = 720
        private const val MIN_FACE_SIZE = 0.12f
        private const val MIN_RELATIVE_FACE_EXTENT = 0.12f
        private const val MIN_RELATIVE_FACE_AREA = 0.015f
        private const val MIN_RELATIVE_EYE_DISTANCE = 0.04f
        private const val MAX_ABS_YAW = 30f
        private const val MAX_ABS_ROLL = 25f
    }
}
