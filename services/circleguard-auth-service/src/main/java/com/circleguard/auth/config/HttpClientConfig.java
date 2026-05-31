package com.circleguard.auth.config;

import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

/**
 * Provides the {@link RestTemplate} used by clients that talk to other
 * CircleGuard services. A small connect/read timeout is configured so that
 * the Resilience4j circuit-breaker sees failures quickly instead of the
 * caller thread being parked for minutes when a peer is unhealthy.
 *
 * <p>Part of Req 3 (Design Patterns) — see {@code docs/PATTERNS.md}.</p>
 */
@Configuration
public class HttpClientConfig {

    @Bean
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder
                .setConnectTimeout(Duration.ofMillis(1_500))
                .setReadTimeout(Duration.ofMillis(2_000))
                .build();
    }
}
