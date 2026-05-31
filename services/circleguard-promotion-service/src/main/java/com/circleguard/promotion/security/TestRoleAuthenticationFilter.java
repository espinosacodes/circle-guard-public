package com.circleguard.promotion.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Profile;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Test-only filter that maps an {@code X-Test-Role} header to a Spring
 * Security authentication. Lets integration tests exercise the role-based
 * authorisation rules without standing up a real JWT issuer.
 *
 * <p>Registered ONLY in the {@code test} Spring profile via
 * {@link Profile @Profile("test")}; the production filter chain never
 * even sees this class instantiated.</p>
 *
 * <p>Header semantics:
 * <pre>
 *   X-Test-Role: HEALTH_CENTER_OFFICER          // single role
 *   X-Test-Role: HEALTH_CENTER_OFFICER,ADMIN    // comma-separated
 * </pre>
 * The Spring convention "hasRole('X')" matches authority "ROLE_X", so we
 * prefix each value automatically.</p>
 */
@Component
@Profile("test")
public class TestRoleAuthenticationFilter extends OncePerRequestFilter {

    public static final String HEADER = "X-Test-Role";

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String header = request.getHeader(HEADER);
        if (header != null && !header.isBlank()) {
            List<SimpleGrantedAuthority> authorities = Arrays.stream(header.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .map(role -> role.startsWith("ROLE_") ? role : "ROLE_" + role)
                    .map(SimpleGrantedAuthority::new)
                    .collect(Collectors.toList());

            UsernamePasswordAuthenticationToken auth =
                    new UsernamePasswordAuthenticationToken("test-user", null, authorities);
            SecurityContextHolder.getContext().setAuthentication(auth);
        }
        chain.doFilter(request, response);
    }
}
