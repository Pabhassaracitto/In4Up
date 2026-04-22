import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(file("../build"))

subprojects {
    project.layout.buildDirectory.set(file("${rootProject.layout.buildDirectory.get()}/${project.name}"))
    project.evaluationDependsOn(":app")

    plugins.withId("com.android.application") {
        extensions.configure<BaseExtension> {
            ndkVersion = "27.0.12077973"
        }
    }

    plugins.withId("com.android.library") {
        extensions.configure<BaseExtension> {
            ndkVersion = "27.0.12077973"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}