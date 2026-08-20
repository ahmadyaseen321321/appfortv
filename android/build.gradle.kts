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
    if (project.name != "app") {
        val forceSdk = {
            if (project.hasProperty("android")) {
                val android = project.extensions.findByName("android")
                if (android is com.android.build.gradle.BaseExtension) {
                    android.compileSdkVersion(36)
                    android.defaultConfig.targetSdkVersion(34)
                }
            }
        }

        if (project.state.executed) {
            forceSdk()
        } else {
            project.afterEvaluate {
                forceSdk()
            }
        }
    }

    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.core" && requested.name == "core") {
                useVersion("1.10.1")
            }
            if (requested.group == "androidx.core" && requested.name == "core-ktx") {
                useVersion("1.10.1")
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
