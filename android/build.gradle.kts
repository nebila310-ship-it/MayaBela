allprojects {
    repositories {
        // Local cache for flutter_embedding_* (avoids flaky DNS to Google during pilot APK builds).
        maven {
            url = uri("${rootProject.projectDir}/../.flutter-maven-local")
        }
        google()
        mavenCentral()
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
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
}

// Do not use afterEvaluate here — with AGP 9 it can mark :app evaluated before
// the Flutter Gradle plugin registers its own afterEvaluate hooks.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
