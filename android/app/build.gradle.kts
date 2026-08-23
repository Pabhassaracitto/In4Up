plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// GitHub Actions đặt biến môi trường CI=true — dùng cho pin CMake dưới đây.
// Bối cảnh (run 32581570950/32582388796, workflow build_final_complete.yml):
// job Android XANH khi tắt native (16m30s, đủ artifact android-apk) nhưng ĐỎ
// khi bật native (chết ở "Build Split APKs" sớm hơn build không-native) ⇒ lỗi
// nằm ở stage CMake/NDK của llama.cpp. SDK của runner ubuntu-latest chỉ preinstall
// cmake 3.31.5 + 4.1.2 (KHÔNG có 3.22.1); bước sdkmanager của workflow cài
// "cmake;3.22.1" kèm `|| true` nên fail âm thầm ⇒ AGP chết "CMake version
// '3.22.1' not found". llama.cpp pin d7fa69b7 khai báo cmake 3.14...3.28 ⇒
// 3.31.5 chạy tốt. Local (không có biến CI) giữ 3.22.1 như cũ.
// (Lỗi Android của build.yml — google-services thiếu client com.in4up.beta +
//  tên rename — xử lý ở workflow, xem KANBAN card CI-ANDROID-01, KHÔNG lách
//  trong repo vì build_final_complete.yml đang dùng `--flavor stable`.)
val in4upCiBuild = System.getenv("CI") == "true"

android {
    namespace = "com.in4up"
    compileSdk = 36 // Đưa lên 36 để đáp ứng các plugin như file_picker, sqflite...

    // NDK 28.2 dùng chung Windows + Linux (bạn yêu cầu giữ 28)
    // CI: runner image ubuntu-latest đã preinstall sẵn NDK 27/28/28.2.13676358/29
    // (không cần bước cài thêm trong workflow)
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.in4up"
        minSdk = 24
        targetSdk = 35
        versionCode = 2
        versionName = "1.0.0"

        // STL cho native build (llama.cpp cần C++ STL). Kotlin DSL dùng
        // `arguments += listOf(...)` — KHÔNG dùng syntax Groovy `arguments("-D...")`.
        externalNativeBuild {
            cmake {
                arguments += listOf("-DANDROID_STL=c++_static")
            }
        }
    }

    flavorDimensions.add("default")

    productFlavors {
        create("stable") {
            dimension = "default"
            applicationIdSuffix = ""
            resValue("string", "app_name", "In4Up")
        }
        create("dev") {
            dimension = "default"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "In4Up Dev")
        }
        create("beta") {
            dimension = "default"
            applicationIdSuffix = ".beta"
            resValue("string", "app_name", "In4Up Beta")
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false 
            isShrinkResources = false 
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.setSrcDirs(listOf("src/main/jniLibs"))
        }
    }
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    // Native backend AI chat (llama.cpp) — file CMake riêng, không đụng
    // CMakeLists của UltraTimeStretch. Nếu thiếu submodule third_party/llama.cpp
    // thì configure chỉ WARNING (không fail) và app fallback mock AI.
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/ai/CMakeLists.txt")
            // SDK của runner ubuntu-latest chỉ có cmake 3.31.5 + 4.1.2 (KHÔNG có
            // 3.22.1) — giữ 3.22.1 thì CI chết "CMake version not found" trước cả
            // khi compile. llama.cpp pin d7fa69b7 khai báo cmake 3.14...3.28 ⇒
            // chạy được với cả 3.22.1 (local) lẫn 3.31.5 (CI).
            version = if (in4upCiBuild) "3.31.5" else "3.22.1"
        }
    }
}

configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
        force("androidx.core:core-ktx:1.15.0")
        force("androidx.core:core:1.15.0")
    }
}

flutter {
    source = "../.."
}