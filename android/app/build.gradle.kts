plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// GitHub Actions đặt biến CI=true — dùng cho 2 sửa CI-only:
//   (1) in4up_ci_fixes.gradle (apply cuối file): build.yml build cả 3 flavor nhưng
//       secret ANDROID_GOOGLE_SERVICES chỉ có client com.in4up (thiếu com.in4up.beta/.dev)
//       ⇒ inject client mock trước task google-services; + copy thêm bản APK không-flavor
//       của stable (build.yml rename chờ tên không-flavor, còn flutter đặt tên
//       app-<abi>-<flavor>-<mode>.apk khi có flavor).
//   (2) pin CMake 3.31.5 trên CI: SDK runner ubuntu-latest chỉ có 3.31.5/4.1.2
//       (KHÔNG có 3.22.1); bước sdkmanager của workflow kèm `|| true` fail âm thầm.
//       llama.cpp khai báo cmake 3.14...3.28 ⇒ 3.31.5 OK. Local giữ 3.22.1.
// Build local (không có biến CI): giữ nguyên 100%.
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

// Sửa CI-only cho build.yml (google-services + rename) — xem in4up_ci_fixes.gradle.
apply(from = "in4up_ci_fixes.gradle")
