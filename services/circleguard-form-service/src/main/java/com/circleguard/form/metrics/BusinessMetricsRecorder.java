package com.circleguard.form.metrics;

import com.circleguard.form.model.HealthSurvey;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.DistributionSummary;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * Thin facade over the Micrometer meters registered in
 * {@link BusinessMetricsConfig}. Centralises the "what does a check-in
 * cost in business metric terms" logic so the service layer keeps
 * compact and so any future caller (a Kafka listener, a scheduled
 * back-fill, etc.) records consistent values.
 *
 * <p>Severity scoring is intentionally simple — it is the kind of thing
 * a product analyst tunes via configuration. Treating fever and cough as
 * 4 points each (capped at 10) is enough to keep the Grafana panel
 * meaningful without leaking a real medical scoring algorithm.</p>
 */
@Component
@RequiredArgsConstructor
public class BusinessMetricsRecorder {

    private final Counter checkinsCounter;
    private final DistributionSummary symptomSeveritySummary;

    /** Bump the check-in counter once per accepted submission. */
    public void recordCheckin() {
        checkinsCounter.increment();
    }

    /**
     * Push a 0..10 severity score into the distribution summary. The
     * value is clamped because Micrometer will happily record garbage.
     */
    public void recordSeverity(double score) {
        double clamped = Math.max(0.0, Math.min(10.0, score));
        symptomSeveritySummary.record(clamped);
    }

    /**
     * Convenience used by the survey-submission path: derive a coarse
     * severity score from the legacy boolean fields on {@link HealthSurvey}
     * and the {@code hasSymptoms} signal computed by the SymptomMapper.
     */
    public void recordFromSurvey(HealthSurvey survey, boolean hasSymptoms) {
        recordCheckin();
        double score = 0.0;
        if (Boolean.TRUE.equals(survey.getHasFever())) score += 4.0;
        if (Boolean.TRUE.equals(survey.getHasCough())) score += 4.0;
        if (hasSymptoms && score == 0.0) score = 2.0;
        recordSeverity(score);
    }
}
