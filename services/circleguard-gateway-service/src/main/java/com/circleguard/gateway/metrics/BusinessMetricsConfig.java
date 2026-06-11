package com.circleguard.gateway.metrics;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PostConstruct;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Micrometer business-domain metrics for the gateway-service.
 *
 * <p>Satisfies Req 7 ("métricas de negocio"). Registers one gauge:</p>
 * <ul>
 *   <li>{@code circleguard.active.circles} — currently active contact
 *       circles, bound to {@link ActiveCirclesHolder#getValue()}.</li>
 * </ul>
 *
 * <p>The holder is exposed as its own bean so downstream code (a Kafka
 * listener, a scheduled poll against the promotion-service) can call
 * {@link ActiveCirclesHolder#set(int)} or
 * {@link ActiveCirclesHolder#getInternal()} to mutate the count, and the
 * gauge will pick it up on the next Prometheus scrape.</p>
 *
 * <p>The gauge is registered with a stub value of 0 at startup so that
 * the metric line appears in the very first {@code /actuator/prometheus}
 * scrape — Prometheus does not back-fill metrics, so we cannot wait for
 * the first business event to register it.</p>
 */
@Configuration
public class BusinessMetricsConfig {

    public static final String ACTIVE_CIRCLES_GAUGE_NAME = "circleguard.active.circles";

    @Bean
    public ActiveCirclesHolder activeCirclesHolder() {
        return new ActiveCirclesHolder();
    }

    @Bean
    public Gauge activeCirclesGauge(MeterRegistry registry, ActiveCirclesHolder holder) {
        return Gauge.builder(ACTIVE_CIRCLES_GAUGE_NAME, holder, h -> h.getInternal().get())
                .description("Currently active CircleGuard contact circles")
                .register(registry);
    }

    /**
     * Mutable holder for the active-circles count. Wraps an
     * {@link AtomicInteger} so Micrometer can sample it lock-free and so
     * setters can be called from any thread.
     */
    public static class ActiveCirclesHolder {
        private final AtomicInteger value = new AtomicInteger(0);

        public AtomicInteger getInternal() {
            return value;
        }

        public int getValue() {
            return value.get();
        }

        public void set(int n) {
            value.set(n);
        }

        public void increment() {
            value.incrementAndGet();
        }

        public void decrement() {
            value.decrementAndGet();
        }

        @PostConstruct
        void initStub() {
            // Wire the stub value at startup so the gauge appears in the
            // first Prometheus scrape even before the first business event.
            value.set(0);
        }
    }
}
