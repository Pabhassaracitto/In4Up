allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(file("../build"))

subprojects {
    project.layout.buildDirectory.set(file("${rootProject.layout.buildDirectory.get()}/${project.name}"))

    val forceNdkVersion = "28.2.13676358"
    val configureNdk = Action<Project> {
        extensions.findByName("android")?.let {
            (it as com.android.build.gradle.BaseExtension).ndkVersion = forceNdkVersion
        }
    }

    if (project.state.executed) configureNdk.execute(project) else project.afterEvaluate(configureNdk)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
