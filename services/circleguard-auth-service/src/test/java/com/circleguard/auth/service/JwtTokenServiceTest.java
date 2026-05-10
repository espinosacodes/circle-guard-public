package com.circleguard.auth.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.security.Key;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * UNIT TEST #1 - JwtTokenService
 *
 * Validates the JWT generator in isolation. No Spring context, no DB, no network.
 * Targets: token subject = anonymousId, claims.permissions, expiration window.
 */
class JwtTokenServiceTest {

    private static final String SECRET = "my-super-secret-test-key-32-chars-long-12345";
    private static final long EXPIRATION_MS = 3_600_000L; // 1 hour

    private JwtTokenService service;
    private Key signingKey;

    @BeforeEach
    void setUp() {
        service = new JwtTokenService(SECRET, EXPIRATION_MS);
        signingKey = Keys.hmacShaKeyFor(SECRET.getBytes());
    }

    @Test
    @DisplayName("Token subject is the anonymousId provided")
    void tokenSubjectIsAnonymousId() {
        UUID anonymousId = UUID.randomUUID();
        Authentication auth = new UsernamePasswordAuthenticationToken("u", "p", List.of());

        String token = service.generateToken(anonymousId, auth);

        Jws<Claims> parsed = Jwts.parserBuilder().setSigningKey(signingKey).build().parseClaimsJws(token);
        assertEquals(anonymousId.toString(), parsed.getBody().getSubject());
    }

    @Test
    @DisplayName("Token includes the user's granted authorities under 'permissions'")
    void tokenIncludesPermissionsClaim() {
        Authentication auth = new UsernamePasswordAuthenticationToken("u", "p",
                List.of(new SimpleGrantedAuthority("ROLE_ADMIN"),
                        new SimpleGrantedAuthority("alert:receive_priority")));

        String token = service.generateToken(UUID.randomUUID(), auth);

        Claims claims = Jwts.parserBuilder().setSigningKey(signingKey).build()
                .parseClaimsJws(token).getBody();
        @SuppressWarnings("unchecked")
        List<String> perms = (List<String>) claims.get("permissions");
        assertNotNull(perms);
        assertTrue(perms.contains("ROLE_ADMIN"));
        assertTrue(perms.contains("alert:receive_priority"));
    }

    @Test
    @DisplayName("Empty authorities produce an empty permissions list (not null)")
    void tokenWithNoAuthoritiesHasEmptyPermissions() {
        Authentication auth = new UsernamePasswordAuthenticationToken("u", "p", List.of());

        String token = service.generateToken(UUID.randomUUID(), auth);

        Claims claims = Jwts.parserBuilder().setSigningKey(signingKey).build()
                .parseClaimsJws(token).getBody();
        @SuppressWarnings("unchecked")
        List<String> perms = (List<String>) claims.get("permissions");
        assertNotNull(perms);
        assertTrue(perms.isEmpty());
    }

    @Test
    @DisplayName("Token expiration falls within the configured window")
    void tokenExpirationIsConfigured() {
        Authentication auth = new UsernamePasswordAuthenticationToken("u", "p", List.of());
        long beforeMs = System.currentTimeMillis();

        String token = service.generateToken(UUID.randomUUID(), auth);

        Claims claims = Jwts.parserBuilder().setSigningKey(signingKey).build()
                .parseClaimsJws(token).getBody();
        Date exp = claims.getExpiration();
        long expectedExpiry = beforeMs + EXPIRATION_MS;
        // Allow 5 second slack
        assertTrue(Math.abs(exp.getTime() - expectedExpiry) < 5_000,
                "expected exp ≈ " + expectedExpiry + " but was " + exp.getTime());
    }

    @Test
    @DisplayName("Token signed with this service can be parsed with the same secret")
    void tokenIsSignedAndVerifiable() {
        UUID anonymousId = UUID.randomUUID();
        Authentication auth = new UsernamePasswordAuthenticationToken("u", "p", List.of());

        String token = service.generateToken(anonymousId, auth);

        // If signature is wrong, parseClaimsJws throws — assertion is implicit
        assertDoesNotThrow(() ->
                Jwts.parserBuilder().setSigningKey(signingKey).build().parseClaimsJws(token));
    }
}
