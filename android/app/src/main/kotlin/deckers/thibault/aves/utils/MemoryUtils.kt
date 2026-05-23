package deckers.thibault.aves.utils

import android.util.Log

object MemoryUtils {
    private val LOG_TAG = LogUtils.createTag<MemoryUtils>()
    private const val HEAP_TYPE_AVAILABLE = "available"
    private const val HEAP_TYPE_USED = "used"
    private const val HEAP_TYPE_TOTAL = "total"
    private const val HEAP_TYPE_MAX = "max"

    fun canAllocate(byteSize: Number?): Boolean {
        byteSize ?: return true
        val availableHeapSize = getAvailableHeapSize()
        val danger = byteSize.toLong() > availableHeapSize
        if (danger) {
            Log.e(LOG_TAG, "trying to handle $byteSize bytes, with only $availableHeapSize free bytes")
        }
        return !danger
    }

    fun getAvailableHeapSize() = getHeapSizes(listOf(HEAP_TYPE_AVAILABLE))[HEAP_TYPE_AVAILABLE] ?: 0

    fun getHeapSizes(types: List<String>): Map<String, Long?> {
        val result = HashMap<String, Long?>()
        val runtime = Runtime.getRuntime()
        val max = runtime.maxMemory()
        val total = runtime.totalMemory()
        val free = runtime.freeMemory()
        val used = total - free
        for (type in types) {
            result[type] = when (type) {
                HEAP_TYPE_AVAILABLE -> max - used
                HEAP_TYPE_USED -> used
                HEAP_TYPE_TOTAL -> total
                HEAP_TYPE_MAX -> max
                else -> null
            }
        }
        return result
    }
}