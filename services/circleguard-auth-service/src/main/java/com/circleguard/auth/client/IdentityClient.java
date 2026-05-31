package com.circleguard.auth.client;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.UUID;

/**
 * Client for the identity-service, the only downstream service the auth-service
 * needs to reach in order to anonymise a real identity into an opaque UUID.
 *
 * <p>Wrapped in Resilience4j Circuit Breaker + Retry (see
 * {@code application.yml -> resilience4j.circuitbreaker.instances.identity-service}).
 * When the breaker is OPEN — i.e. identity-service is failing &gt; failureRateThreshold —
 * all calls short-circuit and route to {@link #fallback(String, Throwable)}, which
 * returns a deterministic placeholder UUID. This keeps login from blocking for the
 * full HTTP timeout when identity-service is down.</p>
 *
 * <p>Pattern: Circuit Breaker (Req 3.a). Documented in {@code docs/PATTERNS.md}.</p>
 */
@Component
@Slf4j
public class IdentityClient {

    /**
     * The placeholder UUID returned by the fallback. It is intentionally
     * fixed so downstream callers can detect "degraded login" if they care.
     */
    public static final UUID FALLBACK_ANONYMOUS_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000000");

    private final RestTemplate restTemplate;
    private final String identityServiceUrl;

    public IdentityClient(RestTemplate restTemplate,
                          @Value("${circleguard.identity-service.url:http://localhost:8083}") String identityServiceUrl) {
        this.restTemplate = restTemplate;
        this.identityServiceUrl = identityServiceUrl;
    }

    @CircuitBreaker(name = "identity-service", fallbackMethod = "fallback")
    @Retry(name = "identity-service")
    @SuppressWarnings("unchecked")
    public UUID getAnonymousId(String realIdentity) {
        String url = identityServiceUrl + "/api/v1/identities/map";
        Map<String, String> request = Map.of("realIdentity", realIdentity);
        Map<String, Object> response = restTemplate.postForObject(url, request, Map.class);
        if (response == null || response.get("anonymousId") == null) {
            throw new IllegalStateException("identity-service returned no anonymousId");
        }
        return UUID.fromString(response.get("anonymousId").toString());
    }

    /**
     * Fallback executed when the circuit-breaker is OPEN or all retries are
     * exhausted. Returns the well-known {@link #FALLBACK_ANONYMOUS_ID} so
     * the caller can still continue (degraded mode) without a 5xx storm.
     */
    @SuppressWarnings("unused")
    UUID fallback(String realIdentity, Throwable ex) {
        log.warn("identity-service unavailable for '{}' (cause: {}). Returning fallback anonymous id.",
                realIdentity, ex.toString());
        return FALLBACK_ANONYMOUS_ID;
    }
}
