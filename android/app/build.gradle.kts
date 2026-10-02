import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseBuildRequested && !keystorePropertiesFile.exists()) {
    throw GradleException(
        "Release signing requires android/key.properties; debug signing is forbidden.",
    )
}
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ababilx.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.ababilx.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // NotificationCompat.CallStyle (androidx.core 1.8+) for the ongoing-call
    // notification, and WindowCompat.enableEdgeToEdge (1.17+) for Android 15.
    // Pinned rather than left to transitive resolution so a plugin bump cannot
    // quietly drop below the version that has them. 1.18.0 is what the release
    // graph already resolved to before this line said so.
    implementation("androidx.core:core-ktx:1.18.0")
    // Signal's Android storage primitive: encrypted SQLite with a
    // Keystore-sealed random passphrase supplied by ChatDatabaseSecret.
    implementation("androidx.sqlite:sqlite:2.6.2")
    // The native media-send flow (gallery grid, review pager, editor). No
    // Material or AppCompat: the screen is fully custom-drawn, exactly like
    // Signal's, and pulling a theme library in for two widgets would drag the
    // whole app's styling with it.
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("androidx.viewpager2:viewpager2:1.1.0")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    implementation("net.zetetic:sqlcipher-android:4.17.0")
    // Direct Share chat pictures (DirectShareImages). The same version the
    // CallKit plugin already ships, so it adds nothing to the APK; Play flags
    // a hand-rolled HttpURLConnection + BitmapFactory pair as a memory risk.
    implementation("io.coil-kt:coil:1.4.0")
    // The in-app camera (mediasend/camera), Signal's CameraX screen rather
    // than a hand-off to whatever camera app the phone ships. 1.6.1 is
    // Signal's own pin and what a plugin already resolves camera-core to.
    // lifecycle-runtime gives CameraLifecycle its LifecycleRegistry: the
    // media-send Activity is a plain Activity, not a LifecycleOwner.
    implementation("androidx.camera:camera-core:1.6.1")
    implementation("androidx.camera:camera-camera2:1.6.1")
    implementation("androidx.camera:camera-lifecycle:1.6.1")
    implementation("androidx.camera:camera-view:1.6.1")
    implementation("androidx.camera:camera-video:1.6.1")
    implementation("androidx.lifecycle:lifecycle-runtime:2.8.7")
}
