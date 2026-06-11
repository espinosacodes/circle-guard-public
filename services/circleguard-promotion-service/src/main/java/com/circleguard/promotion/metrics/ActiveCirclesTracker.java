package com.circleguard.promotion.metrics;

import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.stereotype.Component;

/**
 * Maintains the live count of active (Confirmed-status) circles for the
 * {@code circleguard.active.circles} business gauge.
 *
 * <p>Callers should:</p>
 * <ul>
 *   <li>{@link #recordPromotionToConfirmed()} after a successful
 *       Suspect → Confirmed promotion that opens a new circle.</li>
 *   <li>{@link #recordCircleResolved()} when an end-of-quarantine job
 *       expires a circle (typically after the 14-day TTL).</li>
 *   <li>{@link #setActiveCircles(int)} from a startup reconciler that
 *       reads the persistent count from the graph database so the metric
 *       survives pod restarts.</li>
 * </ul>
 *
 * <p>The holder is a Spring bean (produced by {@link BusinessMetricsConfig#activeCirclesHolder})
 * so Micrometer's Gauge always reads the most recent value via reference.</p>
 */
@Component
public class ActiveCirclesTracker {

    private final AtomicInteger holder;

    public ActiveCirclesTracker(AtomicInteger activeCirclesHolder) {
        this.holder = activeCirclesHolder;
    }

    public void recordPromotionToConfirmed() {
        holder.incrementAndGet();
    }

    public void recordCircleResolved() {
        // Floor at 0 so a duplicate resolve event never makes the metric go negative.
        holder.updateAndGet(curr -> Math.max(0, curr - 1));
    }

    public void setActiveCircles(int value) {
        holder.set(Math.max(0, value));
    }

    public int current() {
        return holder.get();
    }
}
