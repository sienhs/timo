package com.ssafy.timo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Debug
import android.os.SystemClock
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Measurement-only entry points used by integration_test/model_benchmark_test.dart.
 * They reuse the production inference paths so the numbers match what a user gets.
 * Nothing here is reachable from the app UI.
 *
 * The model output is dumped to a file here rather than returned to Dart on purpose:
 * handing back a full-size alpha (about 1.9 MB per photo, 300 photos per run) and
 * re-encoding it through dart:ui killed the app process mid-run. This is report
 * serialization of a model's own output, not app processing logic.
 */
class BenchmarkProcessor(
    private val context: Context,
    private val files: ImageFiles,
    private val person: PersonProcessor,
    private val depth: DepthProcessor,
) {
    /** Full-size alpha of [path] from one engine, written as a grey PNG to [out]. */
    fun segment(path: String, engine: String, out: String): Map<String, Any> {
        val bitmap = files.load(path)
        try {
            val started = SystemClock.elapsedRealtime()
            var inferMs = 0L
            var sessionMs = 0L
            val alpha: Bitmap = when (engine) {
                "modnet" -> {
                    val matting = PortraitMatting(context)
                    val result = matting.alpha(bitmap)
                    inferMs = matting.lastInferMs
                    sessionMs = matting.lastSessionMs
                    result
                }
                "mlkit" -> person.selfieAlpha(bitmap, cleanup = true).also { inferMs = person.lastSelfieMs }
                "mlkit_raw" -> person.selfieAlpha(bitmap, cleanup = false).also { inferMs = person.lastSelfieMs }
                else -> error("unknown engine")
            }
            // Timed before the report dump: the app never writes a grey PNG.
            val totalMs = SystemClock.elapsedRealtime() - started
            try {
                val pixels = IntArray(alpha.width * alpha.height)
                alpha.getPixels(pixels, 0, alpha.width, 0, 0, alpha.width, alpha.height)
                for (i in pixels.indices) {
                    val a = Color.alpha(pixels[i])
                    pixels[i] = Color.rgb(a, a, a)
                }
                val grey = Bitmap.createBitmap(pixels, alpha.width, alpha.height, Bitmap.Config.ARGB_8888)
                try {
                    File(out).parentFile?.mkdirs()
                    File(out).outputStream().use { require(grey.compress(Bitmap.CompressFormat.PNG, 100, it)) }
                } finally { grey.recycle() }
                return mapOf(
                    "engine" to engine, "inferMs" to inferMs, "sessionMs" to sessionMs, "totalMs" to totalMs,
                    "width" to alpha.width, "height" to alpha.height, "out" to out,
                )
            } finally { alpha.recycle() }
        } finally { bitmap.recycle() }
    }

    /** Relative depth of [path] with [model] (null = bundled INT8), raw float32 LE 518x518 to [out]. */
    fun depth(path: String, model: String?, runs: Int, out: String): Map<String, Any> {
        val bitmap = files.load(path)
        try {
            val heapBefore = Debug.getNativeHeapAllocatedSize()
            val (values, timings) = depth.benchmark(bitmap, model, runs)
            val heapAfter = Debug.getNativeHeapAllocatedSize()
            val buffer = ByteBuffer.allocate(values.size * 4).order(ByteOrder.LITTLE_ENDIAN)
            buffer.asFloatBuffer().put(values)
            File(out).parentFile?.mkdirs()
            File(out).writeBytes(buffer.array())
            return timings + mapOf(
                "model" to (model ?: "bundled_int8"), "out" to out,
                "min" to values.min().toDouble(), "max" to values.max().toDouble(),
                "nativeHeapDeltaMb" to (heapAfter - heapBefore) / 1048576.0,
                "pssMb" to Debug.getPss() / 1024.0,
            )
        } finally { bitmap.recycle() }
    }
}
