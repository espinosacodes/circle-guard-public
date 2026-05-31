package com.circleguard.promotion.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Inbound DTO for the Health Center "promote suspect → confirmed" endpoint
 * (CG-012). Anonymity is enforced at the controller level by rejecting
 * any payload whose free-text fields contain a "FirstName LastName" pattern.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HealthCenterPromotionRequest {

    /** Anonymous user id that should be promoted to CONFIRMED. */
    @NotBlank
    private String suspectHashId;

    /** Signed-URL or S3 link pointing at the supporting evidence (e.g. PCR report). */
    @NotBlank
    private String evidenceUrl;

    /** Free-text justification entered by the Health Center officer. */
    @NotBlank
    private String reason;
}
