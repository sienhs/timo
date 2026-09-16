# R8 runs on every release build (the Flutter Gradle plugin sets isMinifyEnabled).
# These two protos are referenced by MediaPipe but not shipped in tasks-vision;
# without the suppressions R8 aborts and no release artifact can be produced.
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
# AutoValue's @Memoized is a compile-time annotation; MediaPipe keeps the reference.
-dontwarn com.google.auto.value.**

# ML Kit, MediaPipe and ONNX Runtime resolve classes reflectively or from JNI,
# edges R8 cannot see. Shrinking them yields ClassNotFoundException at inference.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.mediapipe.** { *; }
-keep class ai.onnxruntime.** { *; }

# Flogger (bundled inside MediaPipe) finds the logging call site by walking the
# stack and skipping frames whose class name starts with its own package. Renaming
# it makes that prefix test never match, so Graph.<clinit> dies with
# "no caller found on the stack" and takes the process with it.
-keep class com.google.common.flogger.** { *; }
-dontwarn com.google.common.flogger.**
