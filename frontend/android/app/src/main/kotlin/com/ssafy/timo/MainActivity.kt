package com.ssafy.timo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val files = ImageFiles(this)
        val person = PersonProcessor(this, files)
        val depth = DepthProcessor(this, files)
        val benchmark = BenchmarkProcessor(this, files, person, depth)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "timo/image_pipeline")
            .setMethodCallHandler { call, result ->
                worker.execute {
                    try {
                        val value: Any? = when (call.method) {
                            "segment" -> person.segment(call.argument<String>("path")!!)
                            "editingSource" -> {
                                val bitmap = files.load(call.argument<String>("path")!!)
                                try { files.save(bitmap, "editing_source") } finally { bitmap.recycle() }
                            }
                            "cropUpperBody" -> person.cropUpperBody(call.argument<String>("path")!!, call.argument<Double>("bottom")!!.toFloat())
                            "analyzePerson" -> person.analyze(call.argument<String>("path")!!)
                            // 합성(배치 계산 + 캔버스 그리기)은 Dart 로 옮겼다.
                            // CompositionService 참고. 여기 남은 것은 모델을
                            // 타야만 하는 일뿐이다.
                            "depth" -> depth.process(call.argument<String>("path")!!)
                            "personDepth" -> depth.processPerson(call.argument<String>("source")!!,
                                call.argument<String>("cutout")!!, call.argument<Map<String, Number>>("crop")!!)
                            "transition" -> TransitionProcessor(this, files).analyze(call.argument<String>("path")!!, call.argument<String>("video")!!)
                            // Measurement only (integration_test/model_benchmark_test.dart); no UI entry point.
                            "benchmarkSegment" -> benchmark.segment(call.argument<String>("path")!!,
                                call.argument<String>("engine")!!, call.argument<String>("out")!!)
                            "benchmarkDepth" -> benchmark.depth(call.argument<String>("path")!!, call.argument<String>("model"),
                                call.argument<Int>("runs") ?: 1, call.argument<String>("out")!!)
                            else -> null
                        }
                        runOnUiThread { if(value == null) result.notImplemented() else result.success(value) }
                    } catch (_: Exception) {
                        // No exception messages, paths, pixels or personal data leave the pipeline.
                        runOnUiThread { result.error("PROCESSING_FAILED", "사진 처리에 실패했어요. 다른 사진으로 다시 시도해주세요.", null) }
                    }
                }
            }
    }
    override fun onDestroy() { worker.shutdown(); super.onDestroy() }
}
