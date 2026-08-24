plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cct.appfortv.flutter_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cct.appfortv.flutter_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Build a separate APK per ABI so each TV box gets a clean,
        // compatible package. A universal fat APK is also produced as fallback.
        splits {
            abi {
                isEnable = true
                reset()
                include("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
                isUniversalApk = true
            }
        }
    }

    buildTypes {
        release {
            // Replace with your own keystore for production builds.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Assign unique versionCodes to each ABI split using the AGP 9.x API
androidComponents {
    onVariants { variant ->
        variant.outputs.forEach { output ->
            val abiFilter = output.filters.find {
                it.filterType == com.android.build.api.variant.FilterConfiguration.FilterType.ABI
            }
            val abiCode = when (abiFilter?.identifier) {
                "armeabi-v7a" -> 1
                "arm64-v8a"   -> 2
                "x86"         -> 3
                "x86_64"      -> 4
                else          -> 0  // universal
            }
            output.versionCode.set((flutter.versionCode ?: 1) * 10 + abiCode)
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Required for native FcmService.kt to compile against Firebase classes
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-messaging-ktx")
}

flutter {
    source = "../.."
}
