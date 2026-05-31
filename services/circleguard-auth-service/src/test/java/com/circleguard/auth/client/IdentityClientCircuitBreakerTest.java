package com.circleguard.auth.client;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import java.io.IOException;
import java.time.Duration;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;

/**
 * Integration test for the Resilience4j Circuit Breaker that wraps {@link IdentityClient}.
 *
 * <p>This proves the Req 3.a "resilience pattern" deliverable by verifying:
 * <ol>
 *   <li>Repeated 5xx responses trip the breaker (CLOSED &rarr; OPEN).</li>
 *   <li>While OPEN the fallback runs and returns {@link IdentityClient#FALLBACK_ANONYMOUS_ID}
 *       instead of bubbling the upstream failure.</li>
 *   <li>After {@code waitDurationInOpenState} the breaker transitions to HALF_OPEN
 *       and, given successful probe calls, returns to CLOSED.</li>
 * </ol>
 * </p>
 */
@SpringBootTest(
        classes = com.circleguard.auth.AuthServiceApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.NONE,
        properties = {
                // Tighten the breaker so the test runs in seconds, not minutes.
                "resilience4j.circuitbreaker.instances.identity-service.slidingWindowSize=10",
                "resilience4j.circuitbreaker.instances.identity-service.minimumNumberOfCalls=5",
                "resilience4j.circuitbreaker.instances.identity-service.failureRateThreshold=50",
                "resilience4j.circuitbreaker.instances.identity-service.waitDurationInOpenState=2s",
                "resilience4j.circuitbreaker.instances.identity-service.permittedNumberOfCallsInHalfOpenState=2",
                "resilience4j.circuitbreaker.instances.identity-service.automaticTransitionFromOpenToHalfOpenEnabled=true",
                "resilience4j.retry.instances.identity-service.maxAttempts=1",
                // Disable the JPA/LDAP layers we don't need for this slice.
                "spring.autoconfigure.exclude=" +
                        "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration," +
                        "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration," +
                        "org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration," +
                        "org.springframework.boot.autoconfigure.ldap.LdapAutoConfiguration," +
                        "org.springframework.boot.autoconfigure.data.ldap.LdapRepositoriesAutoConfiguration," +
                        "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
        }
)
class IdentityClientCircuitBreakerTest {

    private static MockWebServer mockIdentityService;

    @Autowired
    private IdentityClient identityClient;

    @Autowired
    private CircuitBreakerRegistry circuitBreakerRegistry;

    @DynamicPropertySource
    static void registerProps(DynamicPropertyRegistry registry) throws IOException {
        mockIdentityService = new MockWebServer();
        mockIdentityService.start();
        registry.add("circleguard.identity-service.url",
                () -> "http://localhost:" + mockIdentityService.getPort());
    }

    @BeforeEach
    void resetBreaker() {
        circuitBreakerRegistry.circuitBreaker("identity-service").reset();
    }

    @AfterEach
    void noop() {
        // MockWebServer is shared across the (single) test in this class; no
        // per-test cleanup needed. We deliberately do not stop it here because
        // Spring is still holding the dynamic property pointing at it.
    }

    @Test
    void breakerTripsToOpenAfterRepeatedFailuresAndRecoversAfterWait() {
        CircuitBreaker breaker = circuitBreakerRegistry.circuitBreaker("identity-service");

        // 1) Queue a generous number of 5xx responses to drive the failure rate over 50%.
        for (int i = 0; i < 20; i++) {
            mockIdentityService.enqueue(new MockResponse().setResponseCode(503));
        }

        // 2) Call the client repeatedly. Every call must short-circuit to the fallback
        //    (i.e. NOT throw) thanks to fallbackMethod = "fallback".
        for (int i = 0; i < 20; i++) {
            UUID result = identityClient.getAnonymousId("user-" + i);
            assertThat(result)
                    .as("Every call must return the fallback UUID, not throw, on repeated 5xx")
                    .isEqualTo(IdentityClient.FALLBACK_ANONYMOUS_ID);
        }

        // 3) The breaker must now be OPEN.
        assertThat(breaker.getState())
                .as("Breaker should be OPEN after >= failureRateThreshold of failures")
                .isEqualTo(CircuitBreaker.State.OPEN);

        // 4) Wait past waitDurationInOpenState; the breaker should transition to HALF_OPEN
        //    automatically (automaticTransitionFromOpenToHalfOpenEnabled=true).
        await().atMost(Duration.ofSeconds(6)).pollInterval(Duration.ofMillis(200))
                .untilAsserted(() -> assertThat(breaker.getState())
                        .isIn(CircuitBreaker.State.HALF_OPEN, CircuitBreaker.State.CLOSED));

        // 5) Send the 2 permitted probes as successes, breaker should close.
        UUID happyId = UUID.randomUUID();
        for (int i = 0; i < 4; i++) {
            mockIdentityService.enqueue(new MockResponse()
                    .setHeader("Content-Type", "application/json")
                    .setBody("{\"anonymousId\":\"" + happyId + "\"}"));
        }
        // Drive the half-open probes.
        for (int i = 0; i < 2; i++) {
            UUID result = identityClient.getAnonymousId("probe-" + i);
            // Either a real success or — if breaker is still transitioning — the fallback.
            assertThat(result).isNotNull();
        }

        await().atMost(Duration.ofSeconds(5)).pollInterval(Duration.ofMillis(200))
                .untilAsserted(() -> assertThat(breaker.getState())
                        .as("Breaker should close after successful half-open probes")
                        .isEqualTo(CircuitBreaker.State.CLOSED));
    }
}
