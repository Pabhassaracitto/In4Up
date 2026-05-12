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
    // Không ép ndkVersion toàn cục: để AGP + NDK tại sdk.dir/ndk.dir (từ env) quyết định, tránh tải side-by-side khác bản đã cài.
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
