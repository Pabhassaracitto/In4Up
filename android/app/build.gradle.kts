plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.in4up"
    compileSdk = 36 // Đưa lên 36 để đáp ứng các plugin như file_picker, sqflite...

    // NDK 28.2 dùng chung Windows + Linux (bạn yêu cầu giữ 28)
    // CI sẽ cài cả 27 và 28 để tránh lỗi plugin yêu cầu NDK 27
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
            version = "3.22.1"
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