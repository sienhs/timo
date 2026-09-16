plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ssafy.timo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ssafy.timo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ML Kit selfie segmentation + ONNX Runtime 이 요구하는 하한. 메모리
        // 티켓의 온디바이스 처리가 들어오면서 올렸다.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Flutter 의 Gradle 플러그인이 릴리스에 R8 을 이미 켜 둔다. 규칙이
            // 없으면 ML Kit·MediaPipe·ONNX Runtime 의 리플렉션/JNI 진입점이
            // 지워져 추론이 ClassNotFoundException 으로 죽는다.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // 배포 APK 는 arm64 실기기 전용. ONNX Runtime·MediaPipe·Flutter 네이티브
            // 라이브러리가 ABI 3개분 들어가면 254MB 가 되어 GitLab artifact 한도를
            // 넘고 테스터 설치도 무겁다. ndk.abiFilters 는 Flutter Gradle 플러그인이
            // 자기 타깃 3개를 합집합으로 덧붙여 효과가 없으므로 패키징에서 뺀다.
            // debug 는 그대로 두어 x86_64 에뮬레이터 개발이 계속 된다.
            packaging {
                jniLibs {
                    excludes += listOf("lib/armeabi-v7a/**", "lib/x86/**", "lib/x86_64/**")
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// --- 메모리 티켓 온디바이스 처리 ---------------------------------------------
dependencies {
    implementation("com.google.mlkit:segmentation-selfie:16.0.0-beta6")
    implementation("com.google.mlkit:face-detection:16.1.7")
    implementation("com.google.mediapipe:tasks-vision:0.10.32")
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.23.2")
    implementation("androidx.exifinterface:exifinterface:1.4.1")
}

// 추론 모델은 Flutter 에셋이 아니라 Android 에셋으로 들어가야 한다 — 네이티브
// 쪽(DepthProcessor·PortraitMatting)이 AssetManager 로 직접 연다. pubspec 에
// 올리면 같은 파일이 APK 에 두 번 들어간다.
//
// 배포에는 INT8 만 싣는다. FP32 원본은 레포에 없고(.gitignore), 양자화 도구
// (tools/quantize_depth.py·tools/quantize_matting.py)를 돌릴 때만 로컬에 둔다.
val syncDepthModel by tasks.registering(Sync::class) {
    from("../../assets/models") {
        include("depth_anything_v2_vits_int8.onnx", "depth_anything_v2_vits_int8.json", "DEPTH_ANYTHING_LICENSE.txt")
    }
    into(layout.buildDirectory.dir("generated/depthAssets/models"))
}
val syncMattingModel by tasks.registering(Sync::class) {
    from("../../assets/models") {
        include("modnet_photographic_portrait_matting_int8.onnx", "modnet_photographic_portrait_matting_int8.json", "MODNET_LICENSE.txt")
    }
    into(layout.buildDirectory.dir("generated/mattingAssets/models"))
}
android.sourceSets.getByName("main").assets.srcDir(layout.buildDirectory.dir("generated/depthAssets").get().asFile)
android.sourceSets.getByName("main").assets.srcDir(layout.buildDirectory.dir("generated/mattingAssets").get().asFile)
tasks.named("preBuild") { dependsOn(syncDepthModel, syncMattingModel) }
