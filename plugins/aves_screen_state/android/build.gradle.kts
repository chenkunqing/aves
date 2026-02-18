group = "deckers.thibault.aves.aves_screen_state"
version = "1.0-SNAPSHOT"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath(libs.gradle)
        classpath(libs.kotlin.gradlePlugin)
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    // TODO TLAD find how to use `alias(libs.plugins.android.library)`
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "deckers.thibault.aves.aves_screen_state"
    compileSdk = 36

    kotlin {
        jvmToolchain(17)
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }
}
