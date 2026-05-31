package com.circleguard.promotion.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Async ack returned by the Health Center promotion endpoint. The caller
 * uses the correlationId to trace the event through Kafka -> notification
 * fan-out (see GET /api/v1/notifications/by-correlation/{id}).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HealthCenterPromotionResponse {
    private String correlationId;
    private String status;       // "ACCEPTED"
}
