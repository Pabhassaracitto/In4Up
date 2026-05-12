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
        val raw = envNames.firstNotNullOfOrNull { name ->
            System.getenv(name)?.takeIf { it.isNotBlank() }
        } ?: return
        val normalized = raw.replace('\\', '/')
        if (props.getProperty(propKey) != normalized) {
            props.setProperty(propKey, normalized)
            changed = true
        }
    }

    applyEnv(listOf("ANDROID_SDK_ROOT", "ANDROID_HOME"), "sdk.dir")
    applyEnv(listOf("ANDROID_NDK_HOME", "NDK_HOME"), "ndk.dir")
    applyEnv(listOf("FLUTTER_ROOT", "FLUTTER_SDK"), "flutter.sdk")

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
        val properties = Properties()
        val f = file("local.properties")
        if (f.exists()) {
            f.reader(StandardCharsets.UTF_8).use { reader -> properties.load(reader) }
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
