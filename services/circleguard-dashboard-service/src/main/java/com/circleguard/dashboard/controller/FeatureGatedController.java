package com.circleguard.dashboard.controller;

import com.circleguard.dashboard.config.FeatureToggles;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Endpoints whose behaviour is gated by {@link FeatureToggles} (Req 3.b).
 *
 * <p>Kept in a dedicated controller so the toggle demo is self-contained and
 * does not risk breaking the existing {@code AnalyticsController}. Each
 * endpoint either returns its payload or {@code 404 Not Found} when the
 * corresponding toggle is off — that way disabled features are
 * indistinguishable from "endpoint does not exist" to the outside world.</p>
 */
@RestController
@RequestMapping("/api/v1/dashboard")
@RequiredArgsConstructor
public class FeatureGatedController {

    private final FeatureToggles toggles;

    /**
     * Experimental GraphQL ping. Hidden behind
     * {@code features.graphql-endpoint-enabled}.
     */
    @GetMapping("/graphql/ping")
    public ResponseEntity<Map<String, Object>> graphqlPing() {
        if (!toggles.isGraphqlEndpointEnabled()) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(Map.of(
                "feature", "graphql-endpoint",
                "enabled", true,
                "message", "GraphQL endpoint is enabled in this environment."
        ));
    }

    /**
     * Hotspot-map data hook. Hidden behind
     * {@code features.hotspot-map-enabled}. On by default everywhere.
     */
    @GetMapping("/hotspot-map")
    public ResponseEntity<Map<String, Object>> hotspotMap() {
        if (!toggles.isHotspotMapEnabled()) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(Map.of(
                "feature", "hotspot-map",
                "enabled", true,
                "points", java.util.List.of()
        ));
    }

    /**
     * Lightweight introspection endpoint — useful from runbooks to confirm
     * which toggles are live in a given pod after a ConfigMap change.
     */
    @GetMapping("/feature-toggles")
    public ResponseEntity<Map<String, Object>> currentToggles() {
        return ResponseEntity.ok(Map.of(
                "graphqlEndpointEnabled", toggles.isGraphqlEndpointEnabled(),
                "hotspotMapEnabled", toggles.isHotspotMapEnabled()
        ));
    }
}
