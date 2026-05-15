plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vipsound"
   ndkVersion = project.findProperty("ndk.version") as String? ?: "27.0.12077973" 
    // ^ Chọn một bản bạn ĐANG CÓ TRÊN CẢ 2 MÁY hoặc dùng bản mới nhất hiện có.
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.vipsound"
        minSdk = 24
        targetSdk = 35
        versionCode = 2
        versionName = "1.0.0"

        ndk {
             abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
            }
        }

    buildTypes {
    release {
        isMinifyEnabled = false // thử tắt
        isShrinkResources = false //
        // XÓA DÒNG signingConfig NÀY ĐI HOẶC ĐỂ MẶC ĐỊNH
        // signingConfig = signingConfigs.getByName("debug") 
        proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
}

    // externalNativeBuild {
    //     cmake {
    //         path = file("src/main/cpp/CMakeLists.txt")
    //     }
    // }
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