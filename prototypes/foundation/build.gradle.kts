plugins {
    kotlin("multiplatform") version "2.4.21"
    kotlin("plugin.serialization") version "2.4.21"
}
kotlin {
    jvm()
    iosSimulatorArm64 { binaries.framework { baseName = "FoundationProbe" } }
    iosArm64 { binaries.framework { baseName = "FoundationProbe" } }
    jvmToolchain(21)
    sourceSets {
        commonMain.dependencies {
            implementation("com.ionspin.kotlin:bignum:0.3.10")
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.11.0")
            implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.12.0")
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
        }
    }
}
