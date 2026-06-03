package com.circleguard.dashboard;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Integration test for the Feature Toggle pattern (Req 3.b).
 *
 * <p>Spins the full Spring context twice with different
 * {@code features.*} values to prove that:
 * <ul>
 *   <li>When {@code features.graphql-endpoint-enabled=false} the endpoint
 *       returns {@code 404} — i.e. the toggle truly gates the route.</li>
 *   <li>When {@code features.graphql-endpoint-enabled=true} the endpoint
 *       returns the expected payload.</li>
 * </ul>
 * </p>
 */
class FeatureToggleIT {

    @Nested
    @SpringBootTest
    @AutoConfigureMockMvc
    @TestPropertySource(properties = {
            "features.graphql-endpoint-enabled=false",
            "features.hotspot-map-enabled=true",
            // Skip DB autoconfig: this test only cares about controller behaviour.
            "spring.autoconfigure.exclude=" +
                    "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration," +
                    "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration," +
                    "org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration," +
                    "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
    })
    class WhenGraphqlToggleOff {

        @Autowired
        MockMvc mockMvc;

        // AnalyticsService autowires JdbcTemplate, which is normally provided
        // by DataSourceAutoConfiguration. We excluded that to keep this slice
        // light — so mock the bean to satisfy the wiring.
        @MockBean
        JdbcTemplate jdbcTemplate;

        @Test
        void graphqlEndpointIs404() throws Exception {
            mockMvc.perform(get("/api/v1/dashboard/graphql/ping"))
                    .andExpect(status().isNotFound());
        }

        @Test
        void hotspotMapEndpointStillWorks() throws Exception {
            mockMvc.perform(get("/api/v1/dashboard/hotspot-map"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.feature").value("hotspot-map"));
        }

        @Test
        void introspectionReflectsTheCurrentState() throws Exception {
            mockMvc.perform(get("/api/v1/dashboard/feature-toggles"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.graphqlEndpointEnabled").value(false))
                    .andExpect(jsonPath("$.hotspotMapEnabled").value(true));
        }
    }

    @Nested
    @SpringBootTest
    @AutoConfigureMockMvc
    @TestPropertySource(properties = {
            "features.graphql-endpoint-enabled=true",
            "features.hotspot-map-enabled=false",
            "spring.autoconfigure.exclude=" +
                    "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration," +
                    "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration," +
                    "org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration," +
                    "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
    })
    class WhenGraphqlToggleOn {

        @Autowired
        MockMvc mockMvc;

        // Same reason as WhenGraphqlToggleOff — satisfy AnalyticsService's
        // JdbcTemplate dependency without standing up a real DataSource.
        @MockBean
        JdbcTemplate jdbcTemplate;

        @Test
        void graphqlEndpointReturnsPayload() throws Exception {
            mockMvc.perform(get("/api/v1/dashboard/graphql/ping"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.feature").value("graphql-endpoint"))
                    .andExpect(jsonPath("$.enabled").value(true));
        }

        @Test
        void hotspotMapEndpointIs404WhenToggleFlippedOff() throws Exception {
            mockMvc.perform(get("/api/v1/dashboard/hotspot-map"))
                    .andExpect(status().isNotFound());
        }
    }
}
