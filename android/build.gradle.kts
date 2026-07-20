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

// Keep plugin build directories under their own source roots. AGP 9 fails
// configuring unit-test tasks when a Pub cache plugin on C: writes into D:.
// But app module MUST output to root build directory for Flutter CLI to find the APK.
subprojects {
    if (project.name == "app") {
        val appBuildDir: Directory = newBuildDir.dir("app")
        project.layout.buildDirectory.value(appBuildDir)
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
