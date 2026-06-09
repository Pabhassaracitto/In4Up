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
    compileSdk = 36
    ndkVersion = "28.2.13676358"

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

        //ndk {
        //     abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        //    }
        }
        // 1. Phải định nghĩa kích thước (Dimension) trước trong .kts
    flavorDimensions.add("default")

    // 2. Tạo các khuôn đúc (Flavors)
    productFlavors {
        create("stable") {
            dimension = "default"
            applicationIdSuffix = "" // Giữ nguyên ID gốc: com.vipsound
            resValue("string", "app_name", "VipSound")
        }
        
        create("dev") {
            dimension = "default"
            applicationIdSuffix = ".dev" // ID sẽ thành: com.vipsound.dev
            resValue("string", "app_name", "VipSound Dev")
        }

        create("beta") {
            dimension = "default"
            applicationIdSuffix = ".beta" // ID sẽ thành: com.vipsound.beta
            resValue("string", "app_name", "VipSound Beta")
        }
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