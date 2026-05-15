import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.nio.charset.StandardCharsets
import java.util.Properties

/**
 * Ghi đè sdk.dir / ndk.dir / flutter.sdk trong local.properties khi biến môi trường được đặt,
 * để mỗi OS dùng SDK/NDK đúng chỗ mà không phụ thuộc đường dẫn cứng của OS khác.
 *
 * Thứ tự ưu tiên: ANDROID_SDK_ROOT → ANDROID_HOME; ANDROID_NDK_HOME → NDK_HOME; FLUTTER_ROOT → FLUTTER_SDK.
 */
fun Settings.mergeLocalPropertiesFromEnvironment() {
    val propsFile = rootDir.resolve("local.properties")
    val props = Properties()
    if (propsFile.isFile) {
        propsFile.reader(StandardCharsets.UTF_8).use { reader -> props.load(reader) }
    }

    var changed = false

    fun applyEnv(envNames: List<String>, propKey: String) {
        val envValue = envNames.firstNotNullOfOrNull { name ->
            System.getenv(name)?.takeIf { it.isNotBlank() }
        }
        if (envValue != null) {
            val normalized = envValue.replace('\\', '/')
            // Log ra terminal để dễ debug
            println("[VipSound Config] Found $propKey in environment: $normalized")
            if (props.getProperty(propKey) != normalized) {
                props.setProperty(propKey, normalized)
                changed = true
            }
        } else if (props.containsKey(propKey)) { // Nếu không tìm thấy biến môi trường, và local.properties có giá trị, hãy xóa nó.
            props.remove(propKey)
            changed = true
        }
    }

    applyEnv(listOf("ANDROID_SDK_ROOT", "ANDROID_HOME"), "sdk.dir")
    applyEnv(listOf("ANDROID_NDK_HOME", "NDK_HOME"), "ndk.dir")
    applyEnv(listOf("FLUTTER_ROOT", "FLUTTER_SDK"), "flutter.sdk")

    // Cố gắng tự tìm NDK Version từ đường dẫn nếu có ANDROID_NDK_HOME
    val ndkHome = System.getenv("ANDROID_NDK_HOME") ?: System.getenv("NDK_HOME")
    if (ndkHome != null) {
        val version = java.io.File(ndkHome).name
        if (version.matches(Regex("""\d+\.\d+\.\d+"""))) {
            if (props.getProperty("ndk.version") != version) {
                props.setProperty("ndk.version", version)
                changed = true
                println("[VipSound Config] Auto-detected ndk.version: $version")
            }
        }
    } else if (props.containsKey("ndk.version")) {
        // Nếu không có NDK_HOME trong biến môi trường, hãy xóa ndk.version cũ 
        // để tránh xung đột phiên bản giữa các hệ điều hành khác nhau.
        props.remove("ndk.version")
        changed = true
    }

    if (changed) {
        propsFile.parentFile.mkdirs()
        FileOutputStream(propsFile).use { fos ->
            OutputStreamWriter(fos, StandardCharsets.UTF_8).use { writer ->
                props.store(writer, "Merged from environment — see android/settings.gradle.kts")
            }
        }
    }
}

mergeLocalPropertiesFromEnvironment()

pluginManagement {
    val flutterSdkPath = run {
        // Imports ở đầu file không áp dụng trong pluginManagement (Gradle tách scope biên dịch).
        val properties = java.util.Properties()
        val f = file("local.properties")
        if (f.exists()) {
            f.reader(java.nio.charset.StandardCharsets.UTF_8).use { reader -> properties.load(reader) }
        }
        val path = properties.getProperty("flutter.sdk")
            ?: System.getenv("FLUTTER_ROOT")?.takeIf { it.isNotBlank() }
            ?: System.getenv("FLUTTER_SDK")?.takeIf { it.isNotBlank() }
        require(path != null) {
            "Flutter SDK missing: set FLUTTER_ROOT (or FLUTTER_SDK), add flutter.sdk to local.properties, or run \"flutter pub get\"."
        }
        path
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.0" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
