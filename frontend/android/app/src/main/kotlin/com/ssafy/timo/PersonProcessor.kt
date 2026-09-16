package com.ssafy.timo

import android.content.Context
import android.graphics.*
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import java.util.concurrent.TimeUnit
import kotlin.math.*

class PersonProcessor(private val context: Context, private val files: ImageFiles) {
    companion object {
        const val POSE_MODEL = "models/pose_landmarker_lite.task"
        const val VISIBLE = 0.5f
        const val MASK_LOW = 0.12f
        const val MASK_HIGH = 0.88f
    }
    fun segment(path: String): Map<String, Any> {
        val bitmap = files.load(path)
        try {
            val mask = PortraitMatting(context).alpha(bitmap)
            try {
                val pixels = IntArray(bitmap.width * bitmap.height)
                val masks = IntArray(pixels.size)
                bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
                mask.getPixels(masks, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
                var left = bitmap.width; var top = bitmap.height; var right = -1; var bottom = -1
                for (i in pixels.indices) {
                    val alpha = Color.alpha(masks[i])
                    pixels[i] = (pixels[i] and 0x00ffffff) or (alpha shl 24)
                    if (alpha > 12) {
                        val x = i % bitmap.width; val y = i / bitmap.width
                        left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y)
                    }
                }
                require(right > left && bottom > top)
                val out = Bitmap.createBitmap(pixels, bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
                val crop = Bitmap.createBitmap(out, left, top, right-left+1, bottom-top+1)
                val saved = try { files.save(crop, "person_modnet") }
                    finally { if (crop !== out) crop.recycle(); out.recycle() }
                return mapOf("path" to saved, "segmented" to true, "engine" to "modnet",
                    "status" to "정밀 누끼 완료",
                    "crop" to mapOf("left" to left.toDouble()/bitmap.width, "top" to top.toDouble()/bitmap.height,
                        "width" to (right-left+1).toDouble()/bitmap.width, "height" to (bottom-top+1).toDouble()/bitmap.height))
            } finally { mask.recycle() }
        } catch (_: Exception) {
            // Explicit fallback for devices where the local model cannot run.
            return segmentSelfie(path) + mapOf("engine" to "mlkit", "status" to "기본 누끼로 처리했어요")
        } finally { bitmap.recycle() }
    }

    /** ML Kit inference time of the last [selfieAlpha] call, read by the benchmark channel only. */
    var lastSelfieMs = 0L

    /** ML Kit selfie confidence as a full-size ARGB alpha bitmap.
     * [cleanup] applies the app's majority cleanup + smoothstep; false keeps the raw confidence.
     */
    fun selfieAlpha(bitmap: Bitmap, cleanup: Boolean = true): Bitmap {
        val client = Segmentation.getClient(SelfieSegmenterOptions.Builder().setDetectorMode(SelfieSegmenterOptions.SINGLE_IMAGE_MODE).build())
        try {
            val started = android.os.SystemClock.elapsedRealtime()
            val mask = Tasks.await(client.process(InputImage.fromBitmap(bitmap, 0)), 40, TimeUnit.SECONDS)
            lastSelfieMs = android.os.SystemClock.elapsedRealtime() - started
            val raw = FloatArray(mask.width * mask.height)
            mask.buffer.rewind()
            for (i in raw.indices) raw[i] = mask.buffer.float
            // Local majority cleanup removes isolated specks and fills tiny enclosed holes.
            // Soft confidence is retained near edges rather than hard-eroding hair or instruments.
            val alpha = IntArray(raw.size)
            for (y in 0 until mask.height) for (x in 0 until mask.width) {
                val i = y * mask.width + x
                if (!cleanup) {
                    alpha[i] = Color.argb((raw[i].coerceIn(0f, 1f) * 255).roundToInt(), 255, 255, 255)
                    continue
                }
                var sum = 0f; var strong = 0; var count = 0
                for (dy in -1..1) for (dx in -1..1) {
                    val xx = (x + dx).coerceIn(0, mask.width - 1)
                    val yy = (y + dy).coerceIn(0, mask.height - 1)
                    val v = raw[yy * mask.width + xx]
                    sum += v; count++; if (v > MASK_HIGH) strong++
                }
                // A thin finger can have background on most sides. Neighbours
                // may fill a hole, but must not lower the model's own confidence.
                var confidence = max(raw[i], raw[i] * 0.7f + sum / count * 0.3f)
                if (strong >= 7) confidence = max(confidence, 0.95f)
                if (raw[i] < 0.08f && sum / count < 0.08f) confidence = 0f
                val t = ((confidence - MASK_LOW) / (MASK_HIGH - MASK_LOW)).coerceIn(0f, 1f)
                val a = (255 * t * t * (3 - 2 * t)).roundToInt()
                alpha[i] = Color.argb(a, 255, 255, 255)
            }
            val small = Bitmap.createBitmap(alpha, mask.width, mask.height, Bitmap.Config.ARGB_8888)
            val full = Bitmap.createScaledBitmap(small, bitmap.width, bitmap.height, true)
            if (full !== small) small.recycle()
            return full
        } finally { client.close() }
    }

    private fun segmentSelfie(path: String): Map<String, Any> {
        val bitmap = files.load(path)
        try {
            val full = selfieAlpha(bitmap)
            val pixels = IntArray(bitmap.width * bitmap.height)
            val masks = IntArray(pixels.size)
            bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
            full.getPixels(masks, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
            var left = bitmap.width; var top = bitmap.height; var right = 0; var bottom = 0
            for(i in pixels.indices) {
                val a = Color.alpha(masks[i])
                pixels[i] = (pixels[i] and 0x00ffffff) or (a shl 24)
                if(a > 12) { val x = i % bitmap.width; val y = i / bitmap.width; left=min(left,x); right=max(right,x); top=min(top,y); bottom=max(bottom,y) }
            }
            require(right > left && bottom > top)
            val out = Bitmap.createBitmap(pixels, bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
            val crop = Bitmap.createBitmap(out, left, top, right-left+1, bottom-top+1)
            val saved = files.save(crop, "person")
            crop.recycle(); if(!out.isRecycled) out.recycle()
            full.recycle()
            return mapOf("path" to saved, "segmented" to true, "status" to "ML Kit 누끼 완료",
                "crop" to mapOf("left" to left.toDouble()/bitmap.width, "top" to top.toDouble()/bitmap.height,
                    "width" to (right-left+1).toDouble()/bitmap.width, "height" to (bottom-top+1).toDouble()/bitmap.height))
        } finally { bitmap.recycle() }
    }
    /** Cut below the detected pelvis and trim the remaining transparent border.
     * Return coordinates within the previous cutout for exact source-depth alignment.
     */
    fun cropUpperBody(path: String, bottom: Float): Map<String, Any> {
        require(bottom.isFinite() && bottom > 0 && bottom <= 1)
        val bitmap = files.load(path)
        try {
            val limit = (bitmap.height * bottom).roundToInt().coerceIn(1, bitmap.height)
            val pixels = IntArray(bitmap.width * limit)
            bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, limit)
            var left = bitmap.width; var right = -1; var top = limit; var last = -1
            for (i in pixels.indices) if (Color.alpha(pixels[i]) > 12) {
                val x = i % bitmap.width; val y = i / bitmap.width
                left = min(left, x); right = max(right, x); top = min(top, y); last = max(last, y)
            }
            require(right > left && last > top)
            val width = right-left+1; val height = last-top+1
            val upper = Bitmap.createBitmap(bitmap, left, top, width, height)
            try {
                return mapOf("path" to files.save(upper, "person_upper"),
                    "crop" to mapOf("left" to left.toDouble()/bitmap.width, "top" to top.toDouble()/bitmap.height,
                        "width" to width.toDouble()/bitmap.width, "height" to height.toDouble()/bitmap.height))
            } finally { if (upper !== bitmap) upper.recycle() }
        } finally { bitmap.recycle() }
    }

    fun analyze(path: String): Map<String, Any> {
        val bitmap = files.load(path)
        val data = mutableMapOf<String, Any>("cropType" to "UNKNOWN", "confidence" to 0.0, "poseAvailable" to false, "faceAvailable" to false, "width" to bitmap.width, "height" to bitmap.height, "bottomAnchor" to 1.0)
        val faceClient = FaceDetection.getClient(FaceDetectorOptions.Builder().setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE).build())
        try {
            val faces = Tasks.await(faceClient.process(InputImage.fromBitmap(bitmap, 0)), 25, TimeUnit.SECONDS)
            val face = faces.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }
            if(face != null) {
                val box = face.boundingBox
                data["faceCenter"] = mapOf("x" to box.exactCenterX()/bitmap.width, "y" to box.exactCenterY()/bitmap.height)
                data["faceHeight"] = box.height().toDouble()/bitmap.height
                data["faceAvailable"] = true
            }
        } catch (_: Exception) { /* Geometry fallback is explicit in response. */ }
        finally { faceClient.close() }
        try {
            context.assets.open(POSE_MODEL).close()
            val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(BaseOptions.builder().setModelAssetPath(POSE_MODEL).build())
                .setRunningMode(RunningMode.IMAGE).setNumPoses(1).build()
            PoseLandmarker.createFromOptions(context, options).use { pose ->
                val image = BitmapImageBuilder(bitmap).build()
                val result = try { pose.detect(image) } finally { image.close() }
                val points = result.landmarks().firstOrNull()
                if (points != null) {
                    // Raw landmarks let Dart split the depth map into body-part layers without a second inference.
                    data["landmarks"] = points.map { mapOf("x" to it.x().toDouble(), "y" to it.y().toDouble(), "v" to it.visibility().orElse(0f).toDouble()) }
                    fun visible(i: Int) = points[i].visibility().orElse(0f) >= VISIBLE
                    fun center(a: Int, b: Int) = mapOf("x" to (points[a].x()+points[b].x())/2, "y" to (points[a].y()+points[b].y())/2)
                    val shoulders = visible(11) && visible(12)
                    val hips = visible(23) && visible(24)
                    val legs = visible(27) || visible(28) || visible(25) || visible(26)
                    data["cropType"] = if(legs) "FULL_BODY" else if(hips) "HALF_BODY" else if(shoulders && visible(0)) "UPPER_BODY" else "UNKNOWN"
                    data["poseAvailable"] = data["cropType"] != "UNKNOWN"
                    data["confidence"] = listOf(0,11,12,23,24).map { points[it].visibility().orElse(0f).toDouble() }.average()
                    if(shoulders) {
                        data["shoulderCenter"] = center(11,12)
                        data["shoulderWidth"] = abs(points[11].x()-points[12].x())
                    }
                    if(hips) data["hipCenter"] = center(23,24)
                    // Preserve lowered hands when Dart chooses the upper-body crop.
                    // Include wrists as well as the thumb, index and pinky tips.
                    val hands = (15..22).filter {
                        visible(it) && points[it].x() in 0f..1f && points[it].y() in 0f..1f
                    }
                    if (hands.isNotEmpty()) data["handBottom"] = hands.maxOf { points[it].y() }.toDouble()
                    // Torso length is the most view-invariant body-size cue we have.
                    if(shoulders && hips) data["torsoLength"] = abs((points[11].y()+points[12].y())/2 - (points[23].y()+points[24].y())/2).toDouble()
                    if(!data.containsKey("faceCenter") && visible(0)) data["faceCenter"] = mapOf("x" to points[0].x(), "y" to points[0].y())
                    val bottoms = listOf(27,28,25,26,23,24).filter { visible(it) }
                    if(bottoms.isNotEmpty()) data["bottomAnchor"] = bottoms.maxOf { points[it].y() }.coerceIn(0f,1f)
                }
            }
        } catch (_: Exception) { /* Missing/unsupported model: bounding-box composition remains available. */ }
        bitmap.recycle()
        return data
    }
}
