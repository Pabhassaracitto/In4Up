import com.android.build.gradle.BaseExtension
import org.apache.tools.ant.taskdefs.condition.Os
import java.util.Properties

// 1. TỰ ĐỘNG CẬP NHẬT local.properties THEO OS
val localPropsFile = file("local.properties")
val localProps = Properties()

if (localPropsFile.exists()) {
    localPropsFile.inputStream().use { localProps.load(it) }
}

val isWindows = Os.isFamily(Os.FAMILY_WINDOWS)

if (isWindows) {
    localProps.remove("ndk.dir")
} else {
    val linuxSdk = localProps.getProperty("sdk.dir") ?: "/media/pabahassara/MEDIA/LINUX/LIBRARY/Android/Sdk"
    localProps.setProperty("ndk.dir", "$linuxSdk/ndk/27.3.13750724")
}

localPropsFile.outputStream().use { localProps.store(it, "Auto-generated NDK path by Gradle") }


// 2. CẤU HÌNH DỰ ÁN VÀ ÉP NDK CHO TẤT CẢ SUBPROJECTS BEFORE EVALUATE
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(file("../build"))

val targetNdkVersion = if (isWindows) "28.2.13676358" else "27.3.13750724"

subprojects {
    project.layout.buildDirectory.set(file("${rootProject.layout.buildDirectory.get()}/${project.name}"))

    // CHÌA KHÓA Ở ĐÂY: Can thiệp TRƯỚC KHI plugin phụ thuộc (như :jni) kịp đọc config cũ
    beforeEvaluate {
        plugins.withId("com.android.application") {
            extensions.configure<BaseExtension> {
                ndkVersion = targetNdkVersion
            }
        }
        plugins.withId("com.android.library") {
            extensions.configure<BaseExtension> {
                ndkVersion = targetNdkVersion
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}