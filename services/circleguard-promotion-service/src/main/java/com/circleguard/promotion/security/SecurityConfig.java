package com.circleguard.promotion.security;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Promotion-service Spring Security wiring.
 *
 * <p>Production profile assumes the upstream gateway has already verified
 * the JWT and forwarded it as a Bearer token; {@link JwtAuthenticationFilter}
 * just decodes the claims and populates the {@code SecurityContext}.</p>
 *
 * <p>Test profile additionally registers {@link TestRoleAuthenticationFilter},
 * which lets integration tests inject a role via an {@code X-Test-Role}
 * header without issuing real JWTs. The test filter is a no-op outside
 * the {@code test} profile (CG-012).</p>
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthFilter;

    /**
     * Optional in production (only registered in tests). Field-injection is
     * acceptable here because the bean is annotated {@code @Profile("test")}
     * and we want the production filter chain to start cleanly when it's
     * missing.
     */
    @Autowired(required = false)
    private TestRoleAuthenticationFilter testRoleFilter;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(request -> {
                var config = new org.springframework.web.cors.CorsConfiguration();
                config.setAllowedOrigins(java.util.List.of("http://localhost:8081", "http://localhost:8080"));
                config.setAllowedMethods(java.util.List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
                config.setAllowedHeaders(java.util.List.of("*"));
                return config;
            }))
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                // Operational endpoints — open for k8s probes + Prometheus.
                // Limit by network policy / istio at the cluster edge.
                .requestMatchers("/actuator/**").permitAll()
                // CG-012: Health Center officer endpoints — explicit role gate.
                .requestMatchers("/api/v1/promotion/health-center/**").hasRole("HEALTH_CENTER_OFFICER")
                // Existing health endpoints — keep behind generic auth.
                .requestMatchers("/api/v1/health/**").authenticated()
                // Default deny: every other route requires an authenticated principal.
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        // Test-only role injector. Registered AFTER the JWT filter so that
        // a real JWT in the same request still wins.
        if (testRoleFilter != null) {
            http.addFilterAfter(testRoleFilter, JwtAuthenticationFilter.class);
        }
        return http.build();
    }
}
