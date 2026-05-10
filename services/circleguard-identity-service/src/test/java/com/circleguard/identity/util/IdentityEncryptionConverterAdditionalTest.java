package com.circleguard.identity.util;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * UNIT TEST #4 - IdentityEncryptionConverter additional cases (NEW)
 *
 * Existing IdentityEncryptionConverterTest covers happy path. This file adds
 * edge-case coverage for null inputs, unicode, and roundtrip stability.
 * The converter is the privacy core: a regression here leaks real identities.
 */
class IdentityEncryptionConverterAdditionalTest {

    private static final String SECRET = "746573742d7365637265742d33322d63686172732d6c6f6e672d313233343536";
    private static final String SALT   = "deadbeef";

    private IdentityEncryptionConverter converter;

    @BeforeEach
    void setUp() {
        converter = new IdentityEncryptionConverter(SECRET, SALT);
    }

    @Test
    @DisplayName("convertToDatabaseColumn returns null for null input (no NPE)")
    void encryptNullReturnsNull() {
        assertNull(converter.convertToDatabaseColumn(null));
    }

    @Test
    @DisplayName("convertToEntityAttribute returns null for null input (no NPE)")
    void decryptNullReturnsNull() {
        assertNull(converter.convertToEntityAttribute(null));
    }

    @Test
    @DisplayName("Encrypt + decrypt of an ASCII string returns the original")
    void asciiRoundtrip() {
        String original = "1234567890";
        byte[] encrypted = converter.convertToDatabaseColumn(original);
        String decrypted = converter.convertToEntityAttribute(encrypted);
        assertEquals(original, decrypted);
    }

    @Test
    @DisplayName("Encrypt + decrypt of a unicode string survives roundtrip")
    void unicodeRoundtrip() {
        String original = "Estudiante#42 — José Muñoz 你好";
        byte[] encrypted = converter.convertToDatabaseColumn(original);
        String decrypted = converter.convertToEntityAttribute(encrypted);
        assertEquals(original, decrypted);
    }

    @Test
    @DisplayName("Two encryptions of the same plaintext produce different ciphertext (semantic security)")
    void encryptionIsNonDeterministic() {
        String original = "1098765432";
        byte[] cipher1 = converter.convertToDatabaseColumn(original);
        byte[] cipher2 = converter.convertToDatabaseColumn(original);
        // Spring's text Encryptor uses a random IV, so two ciphertexts must differ
        assertFalse(java.util.Arrays.equals(cipher1, cipher2),
                "Identical plaintext encrypted twice must yield different ciphertext");
    }
}
