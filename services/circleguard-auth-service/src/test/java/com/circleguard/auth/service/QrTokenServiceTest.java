package com.circleguard.auth.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.security.Key;
import java.util.Date;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * UNIT TEST #2 - QrTokenService
 *
 * Validates QR-token generation used by Auth Service to produce campus-entry codes
 * consumed by Gateway Service. Pure crypto, no external dependencies.
 */
class QrTokenServiceTest {

    private static final String QR_SECRET = "my-qr-secret-key-for-dev-1234567890-abcdefg";
    private static final long EXPIRATION_MS = 60_000L; // 1 minute

    private QrTokenService service;
    private Key signingKey;

    @BeforeEach
    void setUp() {
        service = new QrTokenService(QR_SECRET, EXPIRATION_MS);
        signingKey = Keys.hmacShaKeyFor(QR_SECRET.getBytes());
    }

    @Test
    @DisplayName("QR token subject is the anonymousId")
    void qrTokenSubjectIsAnonymousId() {
        UUID anonymousId = UUID.randomUUID();

        String token = service.generateQrToken(anonymousId);

        Claims claims = Jwts.parserBuilder().setSigningKey(signingKey).build()
                .parseClaimsJws(token).getBody();
        assertEquals(anonymousId.toString(), claims.getSubject());
    }

    @Test
    @DisplayName("QR token expiration is short (campus-entry tokens must rotate fast)")
    void qrTokenHasShortExpiration() {
        long beforeMs = System.currentTimeMillis();

        String token = service.generateQrToken(UUID.randomUUID());

        Claims claims = Jwts.parserBuilder().setSigningKey(signingKey).build()
                .parseClaimsJws(token).getBody();
        Date exp = claims.getExpiration();
        // Should be ~60s from now
        assertTrue(exp.getTime() - beforeMs <= EXPIRATION_MS + 5_000);
        assertTrue(exp.getTime() - beforeMs >= EXPIRATION_MS - 5_000);
    }

    @Test
    @DisplayName("Each generated QR token is unique even for the same user")
    void qrTokensAreUnique() throws InterruptedException {
        UUID anonymousId = UUID.randomUUID();

        String token1 = service.generateQrToken(anonymousId);
        Thread.sleep(1_001); // JWT iat resolves to seconds — wait >1s
        String token2 = service.generateQrToken(anonymousId);

        assertNotEquals(token1, token2,
                "Two consecutive tokens issued >1s apart must differ (different iat/exp)");
    }
}
