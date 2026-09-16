package com.ssafy.timo
import android.content.Context
import android.graphics.*
import android.media.MediaMetadataRetriever
import kotlin.math.*

class TransitionProcessor(private val context: Context, private val files: ImageFiles) {
    private fun stats(bitmap: Bitmap): DoubleArray {
        val small=Bitmap.createScaledBitmap(bitmap,32,32,true)
        val p=IntArray(1024); small.getPixels(p,0,32,0,0,32,32)
        var r=0.0; var g=0.0; var b=0.0; var saturation=0.0
        val hsv=FloatArray(3)
        p.forEach { r+=Color.red(it); g+=Color.green(it); b+=Color.blue(it); Color.colorToHSV(it,hsv); saturation+=hsv[1] }
        if(small !== bitmap) small.recycle()
        return doubleArrayOf(r/1024,g/1024,b/1024,saturation/1024)
    }
    fun analyze(path:String, video:String): Map<String,Any> {
        val photo=files.load(path)
        val a=stats(photo); photo.recycle()
        var b=a
        var firstFrame=false
        val retriever=MediaMetadataRetriever()
        try {
            if(video.startsWith("assets/")) {
                context.assets.openFd("flutter_assets/$video").use { retriever.setDataSource(it.fileDescriptor,it.startOffset,it.length) }
            } else {
                // Remote video preloading belongs to video_player; do not block creation on a CDN.
                return result(a,b,false)
            }
            val frame=retriever.getFrameAtTime(0)
            if(frame != null) { b=stats(frame); frame.recycle(); firstFrame=true }
        } catch (_:Exception) { } finally { retriever.release() }
        return result(a,b,firstFrame)
    }
    private fun result(a:DoubleArray,b:DoubleArray,firstFrame:Boolean): Map<String,Any> {
        val distance=sqrt((0..2).sumOf { (a[it]-b[it]).pow(2) })/(255*sqrt(3.0))
        val la=0.2126*a[0]+0.7152*a[1]+0.0722*a[2]
        val lb=0.2126*b[0]+0.7152*b[1]+0.0722*b[2]
        return mapOf("brightness" to ((la-lb)/255).coerceIn(-0.2,0.2),"saturation" to (a[3]/max(0.1,b[3])).coerceIn(0.7,1.3),"contrast" to (1+distance*0.15),"tint" to Color.rgb(a[0].toInt(),a[1].toInt(),a[2].toInt()),"durationMs" to (550+150*distance).toInt(),"blur" to (8+distance*4),"distance" to distance,"firstFrameAnalyzed" to firstFrame)
    }
}
