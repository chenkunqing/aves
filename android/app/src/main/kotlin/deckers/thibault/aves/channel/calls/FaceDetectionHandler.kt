package deckers.thibault.aves.channel.calls

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import androidx.core.net.toUri
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DecodeFormat
import com.bumptech.glide.request.RequestOptions
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import deckers.thibault.aves.channel.calls.Coresult.Companion.safe
import deckers.thibault.aves.utils.LogUtils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
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

        try {
            val bitmap = loadThumbnail(uri, width, height)
            if (bitmap == null) {
                result.success(hashMapOf("faceCount" to 0))
                return
            }

            val image = InputImage.fromBitmap(bitmap, 0)
            val options = FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                .build()
            val detector = FaceDetection.getClient(options)

            val faces = kotlinx.coroutines.runBlocking { detector.process(image).await() }

            val bitmapWidth = bitmap.width.toFloat()
            val bitmapHeight = bitmap.height.toFloat()

            val boundingBoxes = JSONArray()
            for (face in faces) {
                val bounds = face.boundingBox
                boundingBoxes.put(JSONObject().apply {
                    put("left", bounds.left / bitmapWidth)
                    put("top", bounds.top / bitmapHeight)
                    put("right", bounds.right / bitmapWidth)
                    put("bottom", bounds.bottom / bitmapHeight)
                })
            }

            result.success(hashMapOf(
                "faceCount" to faces.size,
                "boundingBoxes" to boundingBoxes.toString(),
            ))

            bitmap.recycle()
            detector.close()
        } catch (e: Exception) {
            result.error("detectFaces-exception", e.message, e.stackTraceToString())
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
                .apply(RequestOptions()
                    .format(DecodeFormat.PREFER_RGB_565)
                    .override(targetWidth, targetHeight)
                    .disallowHardwareConfig())
                .submit()
                .get()
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        private val LOG_TAG = LogUtils.createTag<FaceDetectionHandler>()
        const val CHANNEL = "deckers.thibault/aves/face_detection"
        private const val MAX_BITMAP_DIMENSION = 480
    }
}
