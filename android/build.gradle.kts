allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Some plugin modules (e.g. file_picker) pin an older compileSdk (34) while a
    // transitive dep (flutter_plugin_android_lifecycle) now demands compile against
    // API 36. Force every Android library subproject up to 36 so the AAR-metadata
    // check passes without waiting on each plugin to bump its own compileSdk.
    // Registered here (before evaluationDependsOn forces evaluation) so the
    // afterEvaluate callback is not attached to an already-evaluated project.
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            val android = ext as com.android.build.gradle.BaseExtension
            val current = android.compileSdkVersion?.substringAfter("android-")?.toIntOrNull()
            if (current == null || current < 36) {
                android.compileSdkVersion(36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
