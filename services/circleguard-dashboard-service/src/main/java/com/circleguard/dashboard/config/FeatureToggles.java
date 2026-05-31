package com.circleguard.dashboard.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Feature toggles for the dashboard-service (Req 3.b: Configuration pattern).
 *
 * <p>Values are bound from {@code application.yml} under the {@code features:}
 * prefix and overridden per-environment by the K8s ConfigMaps in
 * {@code k8s/<env>/dashboard-service-feature-toggles.yaml}. Flipping a toggle
 * therefore requires only a ConfigMap edit + pod restart (see
 * {@code docs/CHANGE_MANAGEMENT.md}), never a redeploy of the image.</p>
 *
 * <p>To add a new toggle:
 * <ol>
 *   <li>Add a {@code boolean} field with a sensible <em>safe-by-default</em> value.</li>
 *   <li>Add a matching entry under {@code features:} in {@code application.yml}.</li>
 *   <li>Add a {@code FEATURES_<NAME>} env var in the per-env ConfigMap.</li>
 *   <li>Gate the code path with {@code toggles.isXxx()}.</li>
 * </ol>
 * </p>
 */
@ConfigurationProperties(prefix = "features")
public class FeatureToggles {

    /**
     * If true, the experimental GraphQL endpoint
     * ({@code GET /api/v1/dashboard/graphql/ping}) is exposed.
     * Off by default — only flipped on in dev.
     */
    private boolean graphqlEndpointEnabled = false;

    /**
     * If true, the analytics hotspot-map endpoint is exposed. On by default
     * because the React dashboard depends on it.
     */
    private boolean hotspotMapEnabled = true;

    public boolean isGraphqlEndpointEnabled() {
        return graphqlEndpointEnabled;
    }

    public void setGraphqlEndpointEnabled(boolean graphqlEndpointEnabled) {
        this.graphqlEndpointEnabled = graphqlEndpointEnabled;
    }

    public boolean isHotspotMapEnabled() {
        return hotspotMapEnabled;
    }

    public void setHotspotMapEnabled(boolean hotspotMapEnabled) {
        this.hotspotMapEnabled = hotspotMapEnabled;
    }
}
