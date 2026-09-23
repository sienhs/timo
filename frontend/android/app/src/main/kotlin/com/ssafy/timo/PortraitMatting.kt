package com.ssafy.timo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.File
import java.nio.FloatBuffer
import kotlin.math.*

/** Photographic MODNet fine-tuned on P3M-10K. Soft alpha, no confidence erosion.
 * RGB [-1,1], NCHW, dynamic dimensions divisible by 32, output [1,1,H,W].
 * Detached blobs are dropped by [keepMain]; see docs/memory/verification/matting_finetune.
 */
class PortraitMatting(private val context: Context) {
    companion object {
        // INT8 weights rebuilt in-graph as Cast+Mul, built by tools/export_matting.py from the
        // fine-tuned FP32 export: 6.7 MB instead of 26 MB. ONNX Runtime constant-folds the weights
        // at session creation, so compute and the tensor contract are unchanged.
        const val MODEL = "models/modnet_p3m_finetuned_int8.onnx"
        const val SHA256 = "f29b0e32e04bd4fca3fce640fc1a2f5d84c0f26c822a17a37c75d84ff4a07a9c"
        const val MODEL_BYTES = 6734509L
        // Caches left by earlier installs: the official FP32 export and its INT8 build.
        private val STALE_SHA256 = listOf(
            "07c308cf0fc7e6e8b2065a12ed7fc07e1de8febb7dc7839d7b7f15dd66584df9",
            "e8c0a9ca88df6724a93ffc160ad53604e85a4bb81b7ba9eefd37e3bca7da9e6d",
        )
        // Same cut as the cutout bounding box in PersonProcessor.segment (alpha > 12).
        private const val MAIN_THRESHOLD = 12f / 255f
        // A blob survives at this share of the largest one, so two people of similar
        // size both stay while a bystander or watermark fragment does not.
        private const val MAIN_RATIO = 0.3f
    }
    /** Timings of the last [alpha] call, read by the benchmark channel only. */
    var lastSessionMs = 0L
    var lastInferMs = 0L

    private fun modelPath(): String {
        for (stale in STALE_SHA256) listOf(".onnx", ".part").forEach { File(context.cacheDir, "modnet_$stale$it").delete() }
        val target = File(context.cacheDir, "modnet_$SHA256.onnx")
        if (!target.isFile || target.length() != MODEL_BYTES) {
            val partial = File(context.cacheDir, "modnet_$SHA256.part")
            context.assets.open(MODEL).use { input ->
                partial.outputStream().use { output -> input.copyTo(output, 64 * 1024) }
            }
            check(partial.length() == MODEL_BYTES)
            check(partial.renameTo(target))
        }
        return target.absolutePath
    }

    fun alpha(bitmap: Bitmap): Bitmap {
        val w = bitmap.width; val h = bitmap.height
        // Follow photographic inference at a 512px short edge, bounding memory
        // for very tall/wide photos. Keep aspect rather than stretching square.
        val scale = min(512.0 / min(w, h), 1024.0 / max(w, h))
        val width = max(32, (w * scale).toInt() / 32 * 32)
        val height = max(32, (h * scale).toInt() / 32 * 32)
        val scaled = Bitmap.createScaledBitmap(bitmap, width, height, true)
        val pixels = IntArray(width * height)
        scaled.getPixels(pixels, 0, width, 0, 0, width, height)
        if (scaled !== bitmap) scaled.recycle()
        val rgb = FloatArray(pixels.size * 3)
        for (i in pixels.indices) {
            rgb[i] = Color.red(pixels[i]) / 127.5f - 1f
            rgb[pixels.size + i] = Color.green(pixels[i]) / 127.5f - 1f
            rgb[pixels.size * 2 + i] = Color.blue(pixels[i]) / 127.5f - 1f
        }
        val env = OrtEnvironment.getEnvironment()
        OrtSession.SessionOptions().use { options ->
            options.setIntraOpNumThreads(2)
            val sessionStart = android.os.SystemClock.elapsedRealtime()
            env.createSession(modelPath(), options).use { session ->
                lastSessionMs = android.os.SystemClock.elapsedRealtime() - sessionStart
                OnnxTensor.createTensor(env, FloatBuffer.wrap(rgb),
                    longArrayOf(1, 3, height.toLong(), width.toLong())).use { input ->
                    val start = android.os.SystemClock.elapsedRealtime()
                    session.run(mapOf("input" to input)).use { results ->
                        val output = results[0] as OnnxTensor
                        require(output.info.shape.contentEquals(longArrayOf(1, 1, height.toLong(), width.toLong())))
                        val values = FloatArray(pixels.size)
                        output.floatBuffer.get(values)
                        require(values.all { it.isFinite() })
                        require(values.any { it > 0.5f })
                        keepMain(values, width, height)
                        for (i in pixels.indices) {
                            val alpha = (values[i].coerceIn(0f, 1f) * 255).roundToInt()
                            pixels[i] = Color.argb(alpha, 255, 255, 255)
                        }
                        lastInferMs = android.os.SystemClock.elapsedRealtime() - start
                        android.util.Log.i("PortraitMatting", "MODNet ${width}x$height ms=$lastInferMs")
                    }
                }
            }
        }
        val small = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
        val full = Bitmap.createScaledBitmap(small, w, h, true)
        if (full !== small) small.recycle()
        return full
    }

    /** Zero every 8-connected blob of alpha > [MAIN_THRESHOLD] smaller than [MAIN_RATIO] x the largest.
     * The fine-tuned weights also pick up bystanders and watermark fragments apart from the
     * subject. Mirrors keep_main in tools/benchmark_models.py.
     */
    private fun keepMain(values: FloatArray, width: Int, height: Int) {
        val labels = IntArray(values.size)
        val queue = IntArray(values.size)
        val areas = ArrayList<Int>()
        for (start in values.indices) {
            if (labels[start] != 0 || values[start] <= MAIN_THRESHOLD) continue
            val label = areas.size + 1
            labels[start] = label
            var head = 0; var tail = 0
            queue[tail++] = start
            while (head < tail) {
                val i = queue[head++]
                val x = i % width; val y = i / width
                for (yy in max(0, y - 1)..min(height - 1, y + 1)) for (xx in max(0, x - 1)..min(width - 1, x + 1)) {
                    val j = yy * width + xx
                    if (labels[j] == 0 && values[j] > MAIN_THRESHOLD) { labels[j] = label; queue[tail++] = j }
                }
            }
            areas.add(tail)
        }
        if (areas.size <= 1) return
        val minimum = areas.max() * MAIN_RATIO
        for (i in values.indices) if (labels[i] != 0 && areas[labels[i] - 1] < minimum) values[i] = 0f
    }
}
