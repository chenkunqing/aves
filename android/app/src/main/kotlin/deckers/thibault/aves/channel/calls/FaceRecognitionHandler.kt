package deckers.thibault.aves.channel.calls

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Rect
import android.net.Uri
import androidx.core.net.toUri
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DecodeFormat
import com.bumptech.glide.request.RequestOptions
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
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.common.FileUtil
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.sqrt

class FaceRecognitionHandler(private val context: Context) : MethodCallHandler {
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var interpreter: Interpreter? = null
    private var embeddingSize: Int = 0

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "extractEmbeddings" -> ioScope.launch { safe(call, result, ::extractEmbeddings) }
            else -> result.notImplemented()
        }
    }

    private fun getInterpreter(): Interpreter {
        if (interpreter == null) {
            val model = FileUtil.loadMappedFile(context, "models/mobilefacenet.tflite")
            val options = Interpreter.Options().apply {
                numThreads = 4
            }
            val interp = Interpreter(model, options)
            val outputShape = interp.getOutputTensor(0).shape()
            embeddingSize = if (outputShape.size >= 2) outputShape[1] else outputShape[0]
            android.util.Log.d(LOG_TAG, "Model output shape: ${outputShape.contentToString()}, embeddingSize=$embeddingSize")
            interpreter = interp
        }
        return interpreter!!
    }

    private fun extractEmbeddings(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")?.toUri()
        val width = call.argument<Int>("width") ?: 0
        val height = call.argument<Int>("height") ?: 0
        val boundingBoxesJson = call.argument<String>("boundingBoxes")

        if (uri == null || boundingBoxesJson == null) {
            result.error("extractEmbeddings-args", "missing uri or boundingBoxes", null)
            return
        }

        try {
            val bitmap = loadBitmap(uri, width, height)
            if (bitmap == null) {
                result.success(hashMapOf("embeddings" to listOf<ByteArray>()))
                return
            }

            val boxes = JSONArray(boundingBoxesJson)
            val bitmapWidth = bitmap.width.toFloat()
            val bitmapHeight = bitmap.height.toFloat()
            val embeddings = mutableListOf<ByteArray>()

            val interp = getInterpreter()

            for (i in 0 until boxes.length()) {
                val box = boxes.getJSONObject(i)
                val left = (box.getDouble("left") * bitmapWidth).toInt().coerceIn(0, bitmap.width - 1)
                val top = (box.getDouble("top") * bitmapHeight).toInt().coerceIn(0, bitmap.height - 1)
                val right = (box.getDouble("right") * bitmapWidth).toInt().coerceIn(left + 1, bitmap.width)
                val bottom = (box.getDouble("bottom") * bitmapHeight).toInt().coerceIn(top + 1, bitmap.height)

                val faceWidth = right - left
                val faceHeight = bottom - top
                if (faceWidth < 10 || faceHeight < 10) continue

                val faceBitmap = Bitmap.createBitmap(bitmap, left, top, faceWidth, faceHeight)
                val resized = Bitmap.createScaledBitmap(faceBitmap, INPUT_SIZE, INPUT_SIZE, true)
                if (faceBitmap != resized) faceBitmap.recycle()

                val inputBuffer = bitmapToInputBuffer(resized)
                resized.recycle()

                val outputArray = Array(1) { FloatArray(embeddingSize) }
                interp.run(inputBuffer, outputArray)

                val embedding = l2Normalize(outputArray[0])
                embeddings.add(floatArrayToByteArray(embedding))
            }

            bitmap.recycle()

            result.success(hashMapOf("embeddings" to embeddings))
        } catch (e: Exception) {
            result.error("extractEmbeddings-exception", e.message, e.stackTraceToString())
        }
    }

    private fun bitmapToInputBuffer(bitmap: Bitmap): ByteBuffer {
        val buffer = ByteBuffer.allocateDirect(1 * INPUT_SIZE * INPUT_SIZE * 3 * 4)
        buffer.order(ByteOrder.nativeOrder())
        val pixels = IntArray(INPUT_SIZE * INPUT_SIZE)
        bitmap.getPixels(pixels, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)
        for (pixel in pixels) {
            buffer.putFloat(((pixel shr 16 and 0xFF) - 127.5f) / 127.5f)
            buffer.putFloat(((pixel shr 8 and 0xFF) - 127.5f) / 127.5f)
            buffer.putFloat(((pixel and 0xFF) - 127.5f) / 127.5f)
        }
        buffer.rewind()
        return buffer
    }

    private fun l2Normalize(embedding: FloatArray): FloatArray {
        var norm = 0f
        for (v in embedding) norm += v * v
        norm = sqrt(norm)
        if (norm > 0) {
            for (i in embedding.indices) embedding[i] /= norm
        }
        return embedding
    }

    private fun floatArrayToByteArray(floats: FloatArray): ByteArray {
        val buffer = ByteBuffer.allocate(floats.size * 4)
        buffer.order(ByteOrder.nativeOrder())
        for (f in floats) buffer.putFloat(f)
        return buffer.array()
    }

    private fun loadBitmap(uri: Uri, width: Int, height: Int): Bitmap? {
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
                        .format(DecodeFormat.PREFER_ARGB_8888)
                        .override(targetWidth, targetHeight)
                        .disallowHardwareConfig()
                )
                .submit()
                .get()
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        private val LOG_TAG = LogUtils.createTag<FaceRecognitionHandler>()
        const val CHANNEL = "deckers.thibault/aves/face_recognition"
        private const val INPUT_SIZE = 112
        private const val MAX_BITMAP_DIMENSION = 720
    }
}
