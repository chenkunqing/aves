package deckers.thibault.aves.channel.calls

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
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
import org.json.JSONObject
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
    private var activeModel: ModelConfig? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getModelInfo" -> result.success(createModelInfo())
            "extractEmbeddings" -> ioScope.launch { safe(call, result, ::extractEmbeddings) }
            else -> result.notImplemented()
        }
    }

    private fun getActiveModel(): ModelConfig {
        activeModel?.let { return it }

        val availableAssets = context.assets.list(MODEL_ASSET_DIR)?.toSet().orEmpty()
        val selected = MODEL_CANDIDATES.firstOrNull { availableAssets.contains(it.assetFileName) } ?: MODEL_CANDIDATES.last()
        activeModel = selected
        return selected
    }

    private fun getInterpreter(): Interpreter {
        if (interpreter == null) {
            val modelConfig = getActiveModel()
            val model = FileUtil.loadMappedFile(context, modelConfig.assetPath)
            val options = Interpreter.Options().apply {
                numThreads = 4
            }
            val interp = Interpreter(model, options)
            val outputShape = interp.getOutputTensor(0).shape()
            embeddingSize = if (outputShape.size >= 2) outputShape[1] else outputShape[0]
            android.util.Log.d(LOG_TAG, "Model=${modelConfig.version} outputShape=${outputShape.contentToString()}, embeddingSize=$embeddingSize")
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

        var bitmap: Bitmap? = null

        try {
            bitmap = loadBitmap(uri, width, height)
            if (bitmap == null) {
                result.success(
                    hashMapOf(
                        "modelInfo" to createModelInfo(),
                        "embeddings" to listOf<ByteArray>(),
                    )
                )
                return
            }
            val sourceBitmap = bitmap ?: return

            val modelConfig = getActiveModel()
            val boxes = JSONArray(boundingBoxesJson)
            val bitmapWidth = sourceBitmap.width.toFloat()
            val bitmapHeight = sourceBitmap.height.toFloat()
            val embeddings = mutableListOf<ByteArray>()

            val interp = getInterpreter()

            for (i in 0 until boxes.length()) {
                val box = boxes.getJSONObject(i)
                val faceBitmap = createAlignedFaceBitmap(sourceBitmap, bitmapWidth, bitmapHeight, box, modelConfig.inputSize)
                    ?: createFallbackFaceBitmap(sourceBitmap, bitmapWidth, bitmapHeight, box, modelConfig.inputSize)
                    ?: continue

                try {
                    val inputBuffer = bitmapToInputBuffer(faceBitmap, modelConfig.inputSize)

                    val outputArray = Array(1) { FloatArray(embeddingSize) }
                    interp.run(inputBuffer, outputArray)

                    val embedding = l2Normalize(outputArray[0])
                    embeddings.add(floatArrayToByteArray(embedding))
                } finally {
                    faceBitmap.takeUnless { it.isRecycled }?.recycle()
                }
            }

            result.success(
                hashMapOf(
                    "modelInfo" to createModelInfo(),
                    "embeddings" to embeddings,
                )
            )
        } catch (e: Exception) {
            result.error("extractEmbeddings-exception", e.message, e.stackTraceToString())
        } finally {
            bitmap?.takeUnless { it.isRecycled }?.recycle()
        }
    }

    private fun createAlignedFaceBitmap(
        bitmap: Bitmap,
        bitmapWidth: Float,
        bitmapHeight: Float,
        box: JSONObject,
        inputSize: Int,
    ): Bitmap? {
        val landmarks = box.optJSONObject("landmarks") ?: return null
        val leftEye = landmarks.optJSONObject("leftEye") ?: return null
        val rightEye = landmarks.optJSONObject("rightEye") ?: return null
        val nose = landmarks.optJSONObject("nose") ?: return null

        val src = floatArrayOf(
            (leftEye.getDouble("x") * bitmapWidth).toFloat(),
            (leftEye.getDouble("y") * bitmapHeight).toFloat(),
            (rightEye.getDouble("x") * bitmapWidth).toFloat(),
            (rightEye.getDouble("y") * bitmapHeight).toFloat(),
            (nose.getDouble("x") * bitmapWidth).toFloat(),
            (nose.getDouble("y") * bitmapHeight).toFloat(),
        )
        val scale = inputSize / REFERENCE_INPUT_SIZE.toFloat()
        val dst = floatArrayOf(
            REFERENCE_LEFT_EYE_X * scale,
            REFERENCE_LEFT_EYE_Y * scale,
            REFERENCE_RIGHT_EYE_X * scale,
            REFERENCE_RIGHT_EYE_Y * scale,
            REFERENCE_NOSE_X * scale,
            REFERENCE_NOSE_Y * scale,
        )

        val matrix = Matrix()
        if (!matrix.setPolyToPoly(src, 0, dst, 0, 3)) {
            return null
        }

        val output = Bitmap.createBitmap(inputSize, inputSize, Bitmap.Config.ARGB_8888)
        Canvas(output).drawBitmap(bitmap, matrix, ALIGNMENT_PAINT)
        return output
    }

    private fun createFallbackFaceBitmap(
        bitmap: Bitmap,
        bitmapWidth: Float,
        bitmapHeight: Float,
        box: JSONObject,
        inputSize: Int,
    ): Bitmap? {
        val rect = RectF(
            (box.getDouble("left") * bitmapWidth).toFloat(),
            (box.getDouble("top") * bitmapHeight).toFloat(),
            (box.getDouble("right") * bitmapWidth).toFloat(),
            (box.getDouble("bottom") * bitmapHeight).toFloat(),
        )
        val expanded = expandBounds(rect, bitmapWidth, bitmapHeight)
        if (expanded.width() < 10f || expanded.height() < 10f) return null

        val faceBitmap = Bitmap.createBitmap(
            bitmap,
            expanded.left.toInt().coerceAtLeast(0),
            expanded.top.toInt().coerceAtLeast(0),
            expanded.width().toInt().coerceAtLeast(1),
            expanded.height().toInt().coerceAtLeast(1),
        )
        val resized = Bitmap.createScaledBitmap(faceBitmap, inputSize, inputSize, true)
        if (faceBitmap != resized) {
            faceBitmap.recycle()
        }
        return resized
    }

    private fun expandBounds(rect: RectF, bitmapWidth: Float, bitmapHeight: Float): RectF {
        val paddingX = rect.width() * FALLBACK_BOX_PADDING_RATIO
        val paddingY = rect.height() * FALLBACK_BOX_PADDING_RATIO
        return RectF(
            (rect.left - paddingX).coerceAtLeast(0f),
            (rect.top - paddingY).coerceAtLeast(0f),
            (rect.right + paddingX).coerceAtMost(bitmapWidth),
            (rect.bottom + paddingY).coerceAtMost(bitmapHeight),
        )
    }

    private fun createModelInfo() = getActiveModel().toMap()

    private fun bitmapToInputBuffer(bitmap: Bitmap, inputSize: Int): ByteBuffer {
        val buffer = ByteBuffer.allocateDirect(1 * inputSize * inputSize * 3 * 4)
        buffer.order(ByteOrder.nativeOrder())
        val pixels = IntArray(inputSize * inputSize)
        bitmap.getPixels(pixels, 0, inputSize, 0, 0, inputSize, inputSize)
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

    private data class ModelConfig(
        val version: String,
        val assetPath: String,
        val assetFileName: String,
        val inputSize: Int,
        val matchThreshold: Double,
        val mergeThreshold: Double,
    ) {
        fun toMap() = hashMapOf(
            "modelVersion" to version,
            "assetPath" to assetPath,
            "inputSize" to inputSize,
            "matchThreshold" to matchThreshold,
            "mergeThreshold" to mergeThreshold,
        )
    }

    companion object {
        private val LOG_TAG = LogUtils.createTag<FaceRecognitionHandler>()
        private const val MODEL_ASSET_DIR = "models"
        private const val MAX_BITMAP_DIMENSION = 720
        private const val REFERENCE_INPUT_SIZE = 112
        private const val REFERENCE_LEFT_EYE_X = 38.2946f
        private const val REFERENCE_LEFT_EYE_Y = 51.6963f
        private const val REFERENCE_RIGHT_EYE_X = 73.5318f
        private const val REFERENCE_RIGHT_EYE_Y = 51.5014f
        private const val REFERENCE_NOSE_X = 56.0252f
        private const val REFERENCE_NOSE_Y = 71.7366f
        private const val FALLBACK_BOX_PADDING_RATIO = 0.18f

        private val ALIGNMENT_PAINT = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

        private val MODEL_CANDIDATES = listOf(
            ModelConfig(
                version = "buffalo_sc-112x112-v1-aligned",
                assetPath = "models/buffalo_sc_recognition.tflite",
                assetFileName = "buffalo_sc_recognition.tflite",
                inputSize = 112,
                matchThreshold = 0.62,
                mergeThreshold = 0.70,
            ),
            ModelConfig(
                version = "mobilefacenet-112x112-192-v2-aligned",
                assetPath = "models/mobilefacenet.tflite",
                assetFileName = "mobilefacenet.tflite",
                inputSize = 112,
                matchThreshold = 0.55,
                mergeThreshold = 0.63,
            ),
        )

        const val CHANNEL = "deckers.thibault/aves/face_recognition"
    }
}
