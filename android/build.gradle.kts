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

// file_picker (pulled in transitively by stream_chat_flutter, needs its
// >=11.0.0 API) skips self-applying the Kotlin Gradle Plugin whenever AGP is
// 9+ (this project is on 9.0.1) and instead expects Flutter's built-in
// Kotlin to compile it. Several *other* transitive plugins still
// unconditionally self-apply the legacy plugin, which conflicts if built-in
// Kotlin is turned on project-wide (android.builtInKotlin=true in
// gradle.properties) — so instead of a global switch, apply the plugin to
// just this one module directly.
subprojects {
    if (project.name == "file_picker") {
        pluginManager.apply("org.jetbrains.kotlin.android")
        // file_picker's own build.gradle also skips setting kotlinOptions.jvmTarget
        // when AGP >= 9 (same isAgp9OrAbove guard), assuming built-in Kotlin would
        // handle it — leaving the Kotlin compiler at its own default (21) while its
        // Java compileOptions stay pinned at 17. Match Java's 17 explicitly.
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
