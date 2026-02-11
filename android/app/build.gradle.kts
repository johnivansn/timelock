import java.io.ByteArrayOutputStream
import java.time.LocalDate
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
  id("com.android.application")
  id("kotlin-android")
  id("kotlin-kapt")
  id("dev.flutter.flutter-gradle-plugin")
}

android {
  namespace = "io.github.johnivansn.timelock"
  compileSdk = flutter.compileSdkVersion
  ndkVersion = flutter.ndkVersion

  compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlin {
    compilerOptions {
      jvmTarget.set(JvmTarget.JVM_17)
    }
  }

  fun gitOutput(vararg args: String): String? {
    return try {
      val out = ByteArrayOutputStream()
      val execResult = project.providers.exec {
        commandLine("git", *args)
        standardOutput = out
      }.result
      execResult.get()
      out.toString().trim().ifEmpty { null }
    } catch (_: Exception) {
      null
    }
  }

  val autoVersionName = run {
    val commitCount = gitOutput("rev-list", "--count", "HEAD")?.toIntOrNull() ?: 0
    val now = LocalDate.now()
    val year = now.year % 100
    val month = now.monthValue
    val patch = commitCount
    "%02d.%02d.%d".format(year, month, patch)
  }

  val autoVersionCode = run {
    val parts = autoVersionName.split(".")
    val major = parts.getOrNull(0)?.toIntOrNull() ?: 0
    val minor = parts.getOrNull(1)?.toIntOrNull() ?: 0
    val patch = parts.getOrNull(2)?.toIntOrNull() ?: 0
    val computed = (major * 10000) + (minor * 100) + patch
    computed.coerceAtLeast(flutter.versionCode)
  }


  defaultConfig {
    applicationId = "io.github.johnivansn.timelock"
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = autoVersionCode
    versionName = autoVersionName
    multiDexEnabled = true
  }

  signingConfigs {
    create("release") {
      val keystoreFile = rootProject.file("key.properties")
      val props = Properties()
      if (keystoreFile.exists()) {
        keystoreFile.inputStream().use { props.load(it) }
      }
      val storeFilePath = props.getProperty("storeFile")
      storeFile = storeFilePath?.let { rootProject.file(storeFilePath) }
      storePassword = props.getProperty("storePassword")
      keyAlias = props.getProperty("keyAlias")
      keyPassword = props.getProperty("keyPassword")
    }
  }

  buildTypes {
    release {
      signingConfig = signingConfigs.getByName("release")
      isMinifyEnabled = false
      isShrinkResources = false
    }
  }
}

dependencies {
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
  implementation("androidx.constraintlayout:constraintlayout:2.1.4")

  val roomVersion = "2.7.0"
  implementation("androidx.room:room-runtime:$roomVersion")
  implementation("androidx.room:room-ktx:$roomVersion")
  kapt("androidx.room:room-compiler:$roomVersion")

  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
  implementation("com.google.code.gson:gson:2.10.1")
  implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
}

flutter {
  source = "../.."
}
