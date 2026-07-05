// ──────────────────────────────────────────────────────────
// AGP 9.x removed `getDefaultProguardFile('proguard-android.txt')`.
// The flutter_inappwebview_android plugin (transitive dep of
// flutter_osm_plugin) still uses the old name, which breaks the build.
// This patch replaces it with the current name before evaluation.
// ──────────────────────────────────────────────────────────
val pubCacheDir = run {
    val envPub = System.getenv("PUB_CACHE")
    if (envPub != null) file(envPub)
    else file("${System.getProperty("user.home")}/AppData/Local/Pub/Cache")
}
val hostedDir = file("$pubCacheDir/hosted/pub.dev")
hostedDir.listFiles()
    ?.filter { it.name.startsWith("flutter_inappwebview_android-") }
    ?.forEach { pkg ->
        val buildFile = file("$pkg/android/build.gradle")
        if (buildFile.exists()) {
            val original = buildFile.readText()
            val patched = original.replace(
                "getDefaultProguardFile('proguard-android.txt')",
                "getDefaultProguardFile('proguard-android-optimize.txt')"
            )
            if (original != patched) {
                buildFile.writeText(patched)
                logger.lifecycle("✅ Patched $pkg for AGP 9.x proguard compatibility")
            }
        }
    }

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
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

