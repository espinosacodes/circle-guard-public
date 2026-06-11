plugins {
    id("org.springframework.boot")
    id("io.spring.dependency-management")
    kotlin("jvm")
    kotlin("plugin.spring")
    kotlin("plugin.jpa")
}

dependencies {
    implementation(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))
    testImplementation(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))

    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.kafka:spring-kafka")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("io.micrometer:micrometer-registry-prometheus")
    // --- Req 7: Distributed tracing (OTel -> Jaeger) ---
    implementation("io.micrometer:micrometer-tracing-bridge-otel")
    implementation("io.opentelemetry:opentelemetry-exporter-otlp")
    implementation("org.flywaydb:flyway-core")
    runtimeOnly("org.postgresql:postgresql")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    // --- Req 5.b: Consumer-driven contract test (Pact JVM) ---
    testImplementation("au.com.dius.pact.consumer:junit5:4.6.10")
}

tasks.withType<Test> {
    // AttachmentControllerTest loads the full Spring context with Flyway, which
    // requires a real PostgreSQL on localhost. Skipped in the CI pipeline.
    exclude("**/AttachmentControllerTest.class")
}
