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
    // Memaksa semua sub-project (plugins) menggunakan compileSdk 35
    project.afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            try {
                // Gunakan refleksi untuk mendukung berbagai versi AGP
                val method = android?.javaClass?.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                method?.invoke(android, 35)
            } catch (e: Exception) {
                try {
                    val method = android?.javaClass?.getMethod("setCompileSdk", Int::class.javaPrimitiveType)
                    method?.invoke(android, 35)
                } catch (e2: Exception) {}
            }
        }
    }
    
    // Resolusi untuk masalah lifecycle yang meminta API tinggi
    project.configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.lifecycle" && requested.name.startsWith("lifecycle-runtime")) {
                useVersion("2.7.0")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
