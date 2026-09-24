import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// =============================================================================
// KÝ APK RELEASE (card CI-ANDROID-03 — "APK release không cài được").
//
// Root cause: từ commit c5d7adbf (05/2026) khối `release {}` KHÔNG còn dòng
// `signingConfig` nào (chỉ để lại comment "XÓA DÒNG signingConfig NÀY ĐI HOẶC
// ĐỂ MẶC ĐỊNH"). "Mặc định" của AGP cho build type release là KHÔNG KÝ ⇒ AGP
// xuất `app-<flavor>-release-unsigned.apk`; Flutter Gradle plugin (3.44.1,
// FlutterPlugin.kt) copy sang build/app/outputs/flutter-apk/ và ĐỔI TÊN thành
// `app-<flavor>-release.apk` nên hậu tố `-unsigned` bị che mất. Android từ chối
// cài APK không chữ ký ("App not installed" / "package appears to be invalid",
// adb: INSTALL_PARSE_FAILED_NO_CERTIFICATES) — đúng triệu chứng ở CẢ build local
// lẫn artifact GitHub Actions (build.yml / build_final_complete.yml đều không
// có bước ký).
//
// Thứ tự ưu tiên chọn khoá (đọc android/key.properties — file này đã gitignore):
//   (1) android/key.properties tồn tại (local: chủ tự tạo; CI: workflow decode
//       secret ANDROID_KEYSTORE_BASE64 + ghi key.properties — xem
//       scripts/ci/android_prepare_signing.sh) ⇒ ký bằng KEYSTORE RELEASE.
//       ⚠ Đây là cách DUY NHẤT để user cập nhật đè bản cũ (Android yêu cầu cùng
//       chữ ký); giữ file .jks + mật khẩu cẩn thận, mất là mất luôn kênh update.
//   (2) Không có key.properties ⇒ fallback ký bằng DEBUG KEYSTORE (giống template
//       chuẩn của `flutter create`: "Signing with the debug keys for now, so
//       `flutter run --release` works"). APK CÀI ĐƯỢC ngay, nhưng debug key của
//       mỗi máy/mỗi runner khác nhau ⇒ muốn update đè phải gỡ bản cũ. Gradle
//       in WARNING rõ để không ai nhầm đây là bản phát hành thật.
//
// Định dạng android/key.properties (mẫu: android/key.properties.example):
//   storeFile=/duong/dan/tuyet-doi/in4up-release.jks   (hoặc tương đối so với android/app)
//   storePassword=...
//   keyAlias=in4up
//   keyPassword=...
// =============================================================================
val in4upKeystoreProperties = Properties()
val in4upKeystorePropertiesFile = rootProject.file("key.properties")
if (in4upKeystorePropertiesFile.exists()) {
    FileInputStream(in4upKeystorePropertiesFile).use { in4upKeystoreProperties.load(it) }
}

/** storeFile trong key.properties: đường dẫn tuyệt đối HOẶC tương đối so với android/app (như docs Flutter). */
fun in4upResolveStoreFile(raw: String?): File? {
    if (raw.isNullOrBlank()) return null
    val f = File(raw)
    return if (f.isAbsolute) f else project.file(raw)
}

val in4upReleaseStoreFile: File? =
    in4upResolveStoreFile(in4upKeystoreProperties.getProperty("storeFile"))
val in4upHasReleaseKeystore: Boolean =
    (in4upReleaseStoreFile?.exists() == true) &&
        !in4upKeystoreProperties.getProperty("storePassword").isNullOrBlank() &&
        !in4upKeystoreProperties.getProperty("keyAlias").isNullOrBlank() &&
        !in4upKeystoreProperties.getProperty("keyPassword").isNullOrBlank()

if (in4upKeystorePropertiesFile.exists() && !in4upHasReleaseKeystore) {
    logger.warn(
        "[in4up-sign] android/key.properties có nhưng THIẾU/SAI (storeFile không tồn tại " +
            "hoặc thiếu storePassword/keyAlias/keyPassword) → fallback ký bằng DEBUG keystore. " +
            "storeFile=${in4upReleaseStoreFile?.absolutePath}"
    )
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
        // Đọc từ pubspec.yaml (`version: A.B.C+N` ⇒ versionName=A.B.C, versionCode=N)
        // qua local.properties do flutter tool ghi — trước đây cứng `2` / "1.0.0"
        // (SO_TAY_CHU §4 ghi nợ "lần release thật nhớ bỏ cứng"): mọi release đều
        // báo 1.0.0 và versionCode không tăng ⇒ không thể update đè có kiểm soát.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

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

    signingConfigs {
        if (in4upHasReleaseKeystore) {
            create("release") {
                storeFile = in4upReleaseStoreFile
                storePassword = in4upKeystoreProperties.getProperty("storePassword")
                keyAlias = in4upKeystoreProperties.getProperty("keyAlias")
                keyPassword = in4upKeystoreProperties.getProperty("keyPassword")
                // Scheme ký để AGP tự chọn theo minSdk (24 ⇒ v2 + v3, kèm v1 để tương thích).
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false 
            isShrinkResources = false 
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

            // BẮT BUỘC có signingConfig — thiếu dòng này AGP xuất APK *-unsigned
            // (Flutter đổi tên che mất) ⇒ Android không cho cài. Xem khối comment đầu file.
            if (in4upHasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
                logger.lifecycle(
                    "[in4up-sign] release: ký bằng keystore RELEASE " +
                        "(${in4upReleaseStoreFile?.name}, alias=${in4upKeystoreProperties.getProperty("keyAlias")})"
                )
            } else {
                signingConfig = signingConfigs.getByName("debug")
                logger.warn(
                    "[in4up-sign] release: KHÔNG có android/key.properties → ký bằng DEBUG keystore. " +
                        "APK cài được nhưng KHÔNG update đè được bản ký khác key (phải gỡ bản cũ). " +
                        "Bản phát hành thật: tạo keystore + key.properties (xem android/key.properties.example)."
                )
            }
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
