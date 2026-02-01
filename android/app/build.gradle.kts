plugins {
  id("com.android.application")
  id("kotlin-android")
  id("kotlin-kapt")
  id("dev.flutter.flutter-gradle-plugin")
}

android {
  namespace = "com.example.timelock"
  compileSdk = flutter.compileSdkVersion
  ndkVersion = flutter.ndkVersion

  compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlinOptions {
    jvmTarget = JavaVersion.VERSION_17.toString()
  }

  defaultConfig {
    applicationId = "com.example.timelock"
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
    multiDexEnabled = true
  }

  buildTypes {
    release {
      signingConfig = signingConfigs.getByName("debug")
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
  implementation("androidx.work:work-runtime-ktx:2.9.0")
}

flutter {
  source = "../.."
}