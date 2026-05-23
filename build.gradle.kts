plugins {
    id("org.jetbrains.intellij") version "1.17.4"
    kotlin("jvm") version "1.9.25"
}

group = "pim"
version = "1.0.0"

repositories {
    mavenCentral()
}

kotlin {
    jvmToolchain(17)
}

intellij {
    version.set("2024.3")
    type.set("WS")       // WebStorm
    plugins.set(emptyList())
    downloadSources.set(false)
}

tasks {
    patchPluginXml {
        sinceBuild.set("243")
        untilBuild.set("251.*")
    }
    buildSearchableOptions {
        enabled = false  // speeds up build; no settings to index
    }
}
