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

/** Official photographic MODNet export. Soft alpha, no confidence erosion.
 * RGB [-1,1], NCHW, dynamic dimensions divisible by 32, output [1,1,H,W].
 */
class PortraitMatting(private val context: Context) {
    companion object {
        const val MODEL = "models/modnet_photographic_portrait_matting.onnx"
        const val SHA256 = "07c308cf0fc7e6e8b2065a12ed7fc07e1de8febb7dc7839d7b7f15dd66584df9"
        const val MODEL_BYTES = 25888640L
    }
    /** Timings of the last [alpha] call, read by the benchmark channel only. */
    var lastSessionMs = 0L
    var lastInferMs = 0L

    private fun modelPath(): String {
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
}
