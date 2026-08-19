import com.android.build.api.variant.AndroidComponentsExtension
import com.android.build.gradle.BaseExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(file("../build"))

val targetNdkVersion = "28.2.13676358"
val targetCompileSdk = 36

subprojects {
    project.layout.buildDirectory.set(file("${rootProject.layout.buildDirectory.get()}/${project.name}"))

    // Đồng bộ compileSdk, NDK và Java 17 cho tất cả Android modules
    val configureAndroid = {
        val androidComponents = project.extensions.findByType(AndroidComponentsExtension::class.java)
        androidComponents?.finalizeDsl { extension ->
            extension.compileSdk = targetCompileSdk
        }

        val android = project.extensions.findByType(BaseExtension::class.java)
        android?.apply {
            ndkVersion = targetNdkVersion
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    project.plugins.withId("com.android.library") { configureAndroid() }
    project.plugins.withId("com.android.application") { configureAndroid() }

    // ÉP TẤT CẢ TASK BIÊN DỊCH VỀ JAVA 17 (KỂ CẢ VỚI FLUTTER_TTS)
    project.afterEvaluate {
        tasks.withType(JavaCompile::class.java).configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }

        tasks.withType(KotlinCompile::class.java).configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}