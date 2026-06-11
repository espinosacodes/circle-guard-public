package com.circleguard.promotion.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Micrometer business-domain metrics for the promotion-service.
 *
 * <p>Satisfies Req 7 ("métricas de negocio") — Prometheus scrapes
 * {@code /actuator/prometheus} and Grafana renders the values via the
 * dashboard JSON shipped under {@code k8s/observability/}.</p>
 *
 * <p>Two business meters are registered:</p>
 * <ul>
 *   <li>{@code circleguard.promotions.total} — total count of
 *       health-center-driven "suspect → confirmed" promotions, tagged
 *       with {@code source=health-center}.</li>
 *   <li>{@code circleguard.promotion.latency} — wall-clock time spent
 *       inside the promote endpoint, including the Kafka produce.</li>
 * </ul>
 *
 * <p>Both are intentionally registered as beans so callers receive them
 * via constructor injection (matching the project's "no field autowire"
 * style) and so an integration test can verify their presence on the
 * Prometheus scrape page.</p>
 */
@Configuration
public class BusinessMetricsConfig {

    public static final String PROMOTIONS_COUNTER_NAME = "circleguard.promotions.total";
    public static final String PROMOTION_TIMER_NAME = "circleguard.promotion.latency";

    @Bean
    public Counter promotionsCounter(MeterRegistry registry) {
        return Counter.builder(PROMOTIONS_COUNTER_NAME)
                .description("Total CG-012 health-center promotions accepted by the service")
                .tag("source", "health-center")
                .register(registry);
    }

    @Bean
    public Timer promotionLatencyTimer(MeterRegistry registry) {
        return Timer.builder(PROMOTION_TIMER_NAME)
                .description("Latency of the CG-012 promote endpoint, including Kafka produce")
                .tag("source", "health-center")
                .publishPercentiles(0.5, 0.95, 0.99)
                .register(registry);
    }
}
