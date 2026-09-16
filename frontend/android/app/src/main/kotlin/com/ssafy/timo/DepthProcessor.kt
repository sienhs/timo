package com.ssafy.timo

import android.content.Context
import android.graphics.*
import ai.onnxruntime.*
import java.io.File
import java.nio.FloatBuffer
import kotlin.math.*

class DepthProcessor(private val context: Context, private val files: ImageFiles) {
    companion object {
        // Dynamic INT8 (per-channel MatMul weights) built by tools/quantize_depth.py from the
        // pinned FP32 export: 35.6 MB instead of 99 MB, same tensor contract.
        const val MODEL = "models/depth_anything_v2_vits_int8.onnx"
        const val CACHE = "depth_anything_v2_vits_int8"
        const val INPUT = 518
        val MEAN = floatArrayOf(0.485f,0.456f,0.406f)
        val STD = floatArrayOf(0.229f,0.224f,0.225f)
    }
    // Streaming avoids two ~99 MB Java byte arrays (readBytes + toByteArray),
    // which exceed the normal Android heap before inference even starts.
    private val modelPath: String by lazy {
        // Drop the 99 MB FP32 cache left by earlier installs.
        listOf(".onnx", ".version", ".onnx.part").forEach { File(context.cacheDir, "depth_anything_v2_vits$it").delete() }
        val target = File(context.cacheDir, "$CACHE.onnx")
        val stamp = File(context.cacheDir, "$CACHE.version")
        val version = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime.toString()
        if (!target.isFile || target.length() == 0L || !stamp.isFile || stamp.readText() != version) {
            val partial = File(context.cacheDir, "$CACHE.onnx.part")
            context.assets.open(MODEL).use { input ->
                partial.outputStream().use { output -> input.copyTo(output, 64 * 1024) }
            }
            check(partial.renameTo(target))
            stamp.writeText(version)
        }
        target.absolutePath
    }
    // CPU only. Measured on Galaxy S25 (SM-S936N): NNAPI accepts just 48 single-node partitions of
    // the 1015-node INT8 graph (dynamic shapes, MatMulInteger unsupported) and was slower (534 ms vs 500 ms).
    private fun infer(bitmap: Bitmap): FloatArray = inferWith(modelPath, bitmap, 1, null)

    /** Benchmark entry: run [modelFile] (null = bundled INT8) [runs] times on one session.
     * Returns the last output; [timings] receives sessionMs and each run's ms.
     */
    fun benchmark(bitmap: Bitmap, modelFile: String?, runs: Int): Pair<FloatArray, Map<String, Any>> {
        val timings = mutableMapOf<String, Any>()
        val values = inferWith(modelFile ?: modelPath, bitmap, runs, timings)
        return values to timings
    }

    private fun inferWith(modelFile: String, bitmap: Bitmap, runs: Int, timings: MutableMap<String, Any>?): FloatArray {
        val env = OrtEnvironment.getEnvironment()
        OrtSession.SessionOptions().use { options ->
            options.setIntraOpNumThreads(2)
            val sessionStart=android.os.SystemClock.elapsedRealtime()
            env.createSession(modelFile,options).use { session ->
                timings?.put("sessionMs", android.os.SystemClock.elapsedRealtime()-sessionStart)
                val scaled=Bitmap.createScaledBitmap(bitmap,INPUT,INPUT,true)
                val pixels=IntArray(INPUT*INPUT)
                scaled.getPixels(pixels,0,INPUT,0,0,INPUT,INPUT)
                if(scaled !== bitmap) scaled.recycle()
                // RGB float32 NCHW [1,3,518,518], ImageNet mean/std. Output [1,518,518].
                val tensor=FloatArray(INPUT*INPUT*3)
                for(i in pixels.indices) {
                    val p=pixels[i]
                    tensor[i]=(Color.red(p)/255f-MEAN[0])/STD[0]
                    tensor[pixels.size+i]=(Color.green(p)/255f-MEAN[1])/STD[1]
                    tensor[2*pixels.size+i]=(Color.blue(p)/255f-MEAN[2])/STD[2]
                }
                OnnxTensor.createTensor(env,FloatBuffer.wrap(tensor),longArrayOf(1,3,INPUT.toLong(),INPUT.toLong())).use { input ->
                    val runMs = ArrayList<Long>()
                    var values = FloatArray(0)
                    repeat(max(1, runs)) {
                        val started=android.os.SystemClock.elapsedRealtime()
                        session.run(mapOf(session.inputNames.first() to input)).use { output ->
                            val elapsed=android.os.SystemClock.elapsedRealtime()-started
                            runMs.add(elapsed)
                            android.util.Log.i("DepthProcessor","inference cpu ms=$elapsed model=${File(modelFile).name}")
                            val result=output[0] as OnnxTensor
                            require(result.info.shape.contentEquals(longArrayOf(1, INPUT.toLong(), INPUT.toLong())))
                            values=FloatArray(INPUT*INPUT)
                            result.floatBuffer.get(values)
                            require(values.all { it.isFinite() })
                            require(values.maxOrNull()!! - values.minOrNull()!! > 0.00001f)
                        }
                    }
                    timings?.put("runMs", runMs)
                    return values
                }
            }
        }
    }
    /** Infer on the uncut, oriented photo; map the result to the exact segmentation crop.
     * Transparent background pixels never participate in the person depth normalization.
     * Unlike the background fallback, failed inference is reported as unavailable.
     */
    fun processPerson(source: String, cutout: String, crop: Map<String, Number>): Map<String, Any> {
        val photo = files.load(source)
        try {
            val mask = files.load(cutout)
            try {
                val inferred = infer(photo)
                val left = crop.getValue("left").toFloat()
                val top = crop.getValue("top").toFloat()
                val width = crop.getValue("width").toFloat()
                val height = crop.getValue("height").toFloat()
                require(listOf(left, top, width, height).all { it.isFinite() })
                require(left >= 0 && top >= 0 && width > 0 && height > 0 && left + width <= 1.001f && top + height <= 1.001f)
                fun sample(u: Float, v: Float): Float {
                    val x = (u * INPUT - 0.5f).coerceIn(0f, (INPUT-1).toFloat())
                    val y = (v * INPUT - 0.5f).coerceIn(0f, (INPUT-1).toFloat())
                    val x0 = x.toInt(); val y0 = y.toInt()
                    val x1 = min(x0+1, INPUT-1); val y1 = min(y0+1, INPUT-1)
                    val tx = x-x0; val ty = y-y0
                    val a = inferred[y0*INPUT+x0]*(1-tx)+inferred[y0*INPUT+x1]*tx
                    val b = inferred[y1*INPUT+x0]*(1-tx)+inferred[y1*INPUT+x1]*tx
                    return a*(1-ty)+b*ty
                }
                val pixels = IntArray(mask.width*mask.height)
                mask.getPixels(pixels, 0, mask.width, 0, 0, mask.width, mask.height)
                val values = FloatArray(pixels.size) { i ->
                    sample(left + ((i % mask.width)+0.5f)/mask.width*width,
                        top + ((i / mask.width)+0.5f)/mask.height*height)
                }
                // A bounded percentile sample avoids boxing millions of pixels on mobile.
                val stride = max(1, values.size / 16384)
                val foreground = (values.indices step stride).filter { Color.alpha(pixels[it]) > 200 }.map { values[it] }.sorted()
                require(foreground.size > 16)
                val low = foreground[(foreground.size*0.02).toInt()]
                val high = foreground[min(foreground.lastIndex, (foreground.size*0.98).toInt())]
                require(high-low > 0.00001f)
                val colors = IntArray(values.size) { i ->
                    val d = if (Color.alpha(pixels[i]) > 12) ((values[i]-low)/(high-low)*255).roundToInt().coerceIn(0,255) else 128
                    Color.rgb(d, d, d)
                }
                val depthMap = Bitmap.createBitmap(colors, mask.width, mask.height, Bitmap.Config.ARGB_8888)
                try {
                    return mapOf("available" to true, "depthMapPath" to files.save(depthMap, "person_depth"),
                        "width" to mask.width, "height" to mask.height)
                } finally { depthMap.recycle() }
            } finally { mask.recycle() }
        } finally { photo.recycle() }
    }

    // 배경은 Dart(CreationService.renderBackground)가 이미 카드 비율
    // 900x1400 으로 만들어 넘긴다. 예전에는 여기서 비율이 안 맞는 사진에
    // 미러+블러 확장(BackgroundExtender)을 걸었는데, 들어오는 사진이 늘 카드
    // 비율이라 한 번도 걸리지 않았다. 여백 처리는 PhotoFraming 이 한다.
    fun process(path: String): Map<String,Any> {
        val bitmap=files.load(path)
        try {
            var demo=false
            val depth=try { infer(bitmap) } catch (_:Exception) {
                demo=true
                FloatArray(INPUT*INPUT) { i -> (i/INPUT).toFloat()/INPUT }
            }
            val low=depth.minOrNull()!!; val span=max(0.00001f,depth.maxOrNull()!!-low)
            val colors=IntArray(depth.size) { i -> val v=((depth[i]-low)/span*255).roundToInt().coerceIn(0,255); Color.rgb(v,v,v) }
            val map=Bitmap.createBitmap(colors,INPUT,INPUT,Bitmap.Config.ARGB_8888)
            val mapPath=files.save(map,"depth")
            val scaled=Bitmap.createScaledBitmap(map,bitmap.width,bitmap.height,true)
            val values=IntArray(bitmap.width*bitmap.height); val original=IntArray(values.size)
            scaled.getPixels(values,0,bitmap.width,0,0,bitmap.width,bitmap.height)
            bitmap.getPixels(original,0,bitmap.width,0,0,bitmap.width,bitmap.height)
            val layers=(0..2).map { band ->
                val out=IntArray(values.size) { i ->
                    val d=Color.red(values[i])/255f
                    // Overlapping soft bands plus intact backplate prevent parallax holes.
                    val center=(band+0.5f)/3f
                    val alpha=((1f-abs(d-center)/0.26f).coerceIn(0f,1f)*255).toInt()
                    (original[i] and 0xffffff) or (alpha shl 24)
                }
                val layer=Bitmap.createBitmap(out,bitmap.width,bitmap.height,Bitmap.Config.ARGB_8888)
                val saved=files.save(layer,"band$band"); layer.recycle(); saved
            }
            val background=files.save(bitmap,"background")
            if(scaled !== map) scaled.recycle(); map.recycle()
            return mapOf("demo" to demo,"depthMapPath" to mapPath,"layers" to layers,"backgroundPath" to background)
        } finally { bitmap.recycle() }
    }
}
