package com.circleguard.promotion.controller;

import com.circleguard.promotion.dto.HealthCenterPromotionRequest;
import com.circleguard.promotion.dto.HealthCenterPromotionResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * CG-012 — Health Center "promote suspect → confirmed" endpoint.
 *
 * <p>Authorised to Spring Security role {@code HEALTH_CENTER_OFFICER}.
 * Emits a {@code promotion.confirmed} Kafka event with a correlation id
 * so downstream notification fan-out is traceable end-to-end. Returns
 * HTTP 202 Accepted because the side-effect chain (status update +
 * Kafka fan-out + notification dispatch) is async by design.</p>
 *
 * <p>Privacy guard: any free-text field that contains a "FirstName
 * LastName" pattern is rejected with HTTP 422 — the system is
 * anonymous-by-design and real names must never reach the data store.</p>
 */
@RestController
@RequestMapping("/api/v1/promotion/health-center")
@RequiredArgsConstructor
@Slf4j
public class HealthCenterPromotionController {

    /** Topic consumed by notification-service for officer-initiated confirmations. */
    static final String TOPIC_PROMOTION_CONFIRMED = "promotion.confirmed";

    /**
     * Conservative "Two capitalised words separated by whitespace" regex.
     * Tuned to catch common Latin-alphabet real names (e.g. "John Smith",
     * "María García") while staying loose enough for stricter Unicode
     * coverage in a follow-up. Anything that matches => HTTP 422.
     */
    private static final Pattern REAL_NAME_PATTERN = Pattern.compile("[A-Z][a-z]+\\s+[A-Z][a-z]+");

    private final KafkaTemplate<String, Object> kafkaTemplate;

    @PostMapping("/promote")
    @PreAuthorize("hasRole('HEALTH_CENTER_OFFICER')")
    public ResponseEntity<?> promote(@Valid @RequestBody HealthCenterPromotionRequest body) {
        // ---- 1. Privacy guard: reject any real-name leakage --------------
        if (containsRealName(body.getReason()) || containsRealName(body.getEvidenceUrl())) {
            log.warn("Rejecting promotion request — real-name pattern detected (suspectHashId={})",
                    body.getSuspectHashId());
            return ResponseEntity.unprocessableEntity().body(Map.of(
                    "error", "UNPROCESSABLE_ENTITY",
                    "message", "Real names are not allowed in request payload (anonymous-by-design)."
            ));
        }

        // ---- 2. Build the Kafka event with a correlation id --------------
        String correlationId = UUID.randomUUID().toString();
        Map<String, Object> event = new HashMap<>();
        event.put("suspectHashId", body.getSuspectHashId());
        event.put("evidenceUrl",   body.getEvidenceUrl());
        event.put("reason",        body.getReason());
        event.put("correlationId", correlationId);
        event.put("source",        "health-center-officer");
        event.put("timestamp",     System.currentTimeMillis());

        kafkaTemplate.send(TOPIC_PROMOTION_CONFIRMED, body.getSuspectHashId(), event);
        log.info("Emitted promotion.confirmed event correlationId={} suspectHashId={}",
                correlationId, body.getSuspectHashId());

        // ---- 3. 202 Accepted + correlation id for trace lookup -----------
        HealthCenterPromotionResponse response = HealthCenterPromotionResponse.builder()
                .correlationId(correlationId)
                .status("ACCEPTED")
                .build();

        return ResponseEntity.status(HttpStatus.ACCEPTED).body(response);
    }

    private static boolean containsRealName(String s) {
        return s != null && REAL_NAME_PATTERN.matcher(s).find();
    }
}
