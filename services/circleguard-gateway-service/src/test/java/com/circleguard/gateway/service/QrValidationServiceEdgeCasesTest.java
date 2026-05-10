package com.circleguard.gateway.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.test.util.ReflectionTestUtils;

import java.security.Key;
import java.util.Date;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * UNIT TEST #5 - QrValidationService edge cases (NEW)
 *
 * Existing QrValidationServiceTest covers happy path (CLEAR) and CONTAGIED.
 * This adds malformed-input, expired-token and missing-status coverage —
 * the gate must fail-closed on any error.
 */
class QrValidationServiceEdgeCasesTest {

    private static final String SECRET = "my-super-secret-test-key-32-chars-long-12345";
    private QrValidationService service;
    private ValueOperations<String, String> valueOps;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        StringRedisTemplate redis = Mockito.mock(StringRedisTemplate.class);
        valueOps = Mockito.mock(ValueOperations.class);
        Mockito.when(redis.opsForValue()).thenReturn(valueOps);
        service = new QrValidationService(redis);
        ReflectionTestUtils.setField(service, "qrSecret", SECRET);
    }

    @Test
    @DisplayName("Garbage token string is rejected with RED status")
    void rejectsGarbageToken() {
        QrValidationService.ValidationResult r = service.validateToken("not.a.token");
        assertFalse(r.valid());
        assertEquals("RED", r.status());
        assertTrue(r.message().toLowerCase().contains("invalid"));
    }

    @Test
    @DisplayName("Empty token string is rejected with RED status")
    void rejectsEmptyToken() {
        QrValidationService.ValidationResult r = service.validateToken("");
        assertFalse(r.valid());
        assertEquals("RED", r.status());
    }

    @Test
    @DisplayName("Token signed with a different secret is rejected")
    void rejectsTokenWithBadSignature() {
        Key wrongKey = Keys.hmacShaKeyFor("a-different-secret-key-32-chars-long-12345".getBytes());
        String token = Jwts.builder()
                .setSubject(UUID.randomUUID().toString())
                .signWith(wrongKey, SignatureAlgorithm.HS256)
                .compact();

        QrValidationService.ValidationResult r = service.validateToken(token);
        assertFalse(r.valid());
        assertEquals("RED", r.status());
    }

    @Test
    @DisplayName("Expired token is rejected")
    void rejectsExpiredToken() {
        Key key = Keys.hmacShaKeyFor(SECRET.getBytes());
        String token = Jwts.builder()
                .setSubject(UUID.randomUUID().toString())
                .setIssuedAt(new Date(System.currentTimeMillis() - 10_000))
                .setExpiration(new Date(System.currentTimeMillis() - 5_000))
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();

        QrValidationService.ValidationResult r = service.validateToken(token);
        assertFalse(r.valid());
        assertEquals("RED", r.status());
    }

    @Test
    @DisplayName("User with POTENTIAL status is denied entry")
    void denyPotentialStatus() {
        String anonymousId = UUID.randomUUID().toString();
        Key key = Keys.hmacShaKeyFor(SECRET.getBytes());
        String token = Jwts.builder().setSubject(anonymousId)
                .signWith(key, SignatureAlgorithm.HS256).compact();
        Mockito.when(valueOps.get("user:status:" + anonymousId)).thenReturn("POTENTIAL");

        QrValidationService.ValidationResult r = service.validateToken(token);
        assertFalse(r.valid());
        assertEquals("RED", r.status());
    }

    @Test
    @DisplayName("User with no status entry in Redis is allowed (fail-open default)")
    void allowsAccessWhenNoStatusInRedis() {
        String anonymousId = UUID.randomUUID().toString();
        Key key = Keys.hmacShaKeyFor(SECRET.getBytes());
        String token = Jwts.builder().setSubject(anonymousId)
                .signWith(key, SignatureAlgorithm.HS256).compact();
        Mockito.when(valueOps.get("user:status:" + anonymousId)).thenReturn(null);

        QrValidationService.ValidationResult r = service.validateToken(token);
        // Implementation only blocks CONTAGIED/POTENTIAL → null status falls through to GREEN
        assertTrue(r.valid());
        assertEquals("GREEN", r.status());
    }
}
