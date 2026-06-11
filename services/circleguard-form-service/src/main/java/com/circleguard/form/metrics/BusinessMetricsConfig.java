package com.circleguard.form.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.DistributionSummary;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Micrometer business-domain metrics for the form-service.
 *
 * <p>Satisfies Req 7 ("métricas de negocio"). Two domain meters are
 * registered:</p>
 * <ul>
 *   <li>{@code circleguard.checkins.rate} — Counter incremented on each
 *       survey submission. The Grafana dashboard renders the per-minute
 *       rate via {@code rate(circleguard_checkins_rate_total[1m])}.</li>
 *   <li>{@code circleguard.symptom.severity} — DistributionSummary that
 *       records a 0..10 severity score derived from the responses. Lets
 *       us track p50/p95 severity across a campus over time.</li>
 * </ul>
 *
 * <p>Both meters are exposed as Spring beans and accessed through
 * {@link BusinessMetricsRecorder} so any service or scheduled task that
 * needs to record a check-in can do so without re-deriving the meters.</p>
 */
@Configuration
public class BusinessMetricsConfig {

    public static final String CHECKINS_COUNTER_NAME = "circleguard.checkins.rate";
    public static final String SYMPTOM_SEVERITY_SUMMARY_NAME = "circleguard.symptom.severity";

    @Bean
    public Counter checkinsCounter(MeterRegistry registry) {
        return Counter.builder(CHECKINS_COUNTER_NAME)
                .description("Total health survey submissions accepted by the form-service")
                .register(registry);
    }

    @Bean
    public DistributionSummary symptomSeveritySummary(MeterRegistry registry) {
        return DistributionSummary.builder(SYMPTOM_SEVERITY_SUMMARY_NAME)
                .description("Symptom severity score, 0 (asymptomatic) to 10 (severe)")
                .baseUnit("score")
                .minimumExpectedValue(0.0)
                .maximumExpectedValue(10.0)
                .publishPercentiles(0.5, 0.95)
                .register(registry);
    }
}
