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

// Flutter's PluginHandler still calls pluginProject.afterEvaluate(). Without this,
// Gradle may evaluate plugin modules first and the Flutter Gradle plugin crashes
// with "project is already evaluated". Match the Flutter 3.47 app template:
// do not wrap this in afterEvaluate (that is what marks :app evaluated too early).
subprojects {
    if (path != ":app") {
        evaluationDependsOn(":app")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
