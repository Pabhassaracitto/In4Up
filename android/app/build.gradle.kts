import org.apache.tools.ant.taskdefs.condition.Os

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

    // Tự động chọn NDK theo OS đang chạy
    // Chỉ dùng ndkVersion, KHÔNG dùng ndkPath ở đây để tránh xung đột [CXX1100]
    if (Os.isFamily(Os.FAMILY_WINDOWS)) {
        ndkVersion = "28.2.13676358"
    } else {
        ndkVersion = "27.3.13750724"
    }

    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vipsound"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 35
        versionCode = 2
        versionName = "1.0.0"

        // ndk {
        //     abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        // }
    }

    // 1. Định nghĩa kích thước (Dimension) nằm trong android { ... }
    flavorDimensions.add("default")

    // 2. Các khuôn đúc (Flavors) nằm trong android { ... }
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

    // 3. Khối buildTypes đã được đưa về đúng vị trí bên trong android { ... }
    buildTypes {
        getByName("release") { // Đã sửa thành cú pháp chuẩn của Kotlin (.kts)
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            isMinifyEnabled = false 
            isShrinkResources = false 
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // externalNativeBuild {
    //     cmake {
    //         path = file("src/main/cpp/CMakeLists.txt")
    //     }
    // }
    sourceSets {
        getByName("main") {
            jniLibs.setSrcDirs(listOf("src/main/jniLibs"))
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