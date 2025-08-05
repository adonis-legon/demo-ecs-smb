package com.example.scheduledfilewriter.model;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import java.util.Set;

class SMBConnectionConfigTest {

    private SMBConnectionConfig config;
    private Validator validator;

    @BeforeEach
    void setUp() {
        ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @Test
    void testDefaultConstructor() {
        config = new SMBConnectionConfig();

        assertNull(config.getServerAddress());
        assertNull(config.getShareName());
        assertNull(config.getUsername());
        assertNull(config.getPassword());
        assertNull(config.getDomain());
        assertEquals(30, config.getTimeout());
    }

    @Test
    void testConstructorWithBasicParameters() {
        String serverAddress = "192.168.1.100";
        String shareName = "shared";
        String username = "testuser";
        String password = "testpass";

        config = new SMBConnectionConfig(serverAddress, shareName, username, password);

        assertEquals(serverAddress, config.getServerAddress());
        assertEquals(shareName, config.getShareName());
        assertEquals(username, config.getUsername());
        assertEquals(password, config.getPassword());
        assertEquals("WORKGROUP", config.getDomain());
        assertEquals(30, config.getTimeout());
    }

    @Test
    void testFullConstructor() {
        String serverAddress = "192.168.1.100";
        String shareName = "shared";
        String username = "testuser";
        String password = "testpass";
        String domain = "TESTDOMAIN";
        Integer timeout = 60;

        config = new SMBConnectionConfig(serverAddress, shareName, username, password, domain, timeout);

        assertEquals(serverAddress, config.getServerAddress());
        assertEquals(shareName, config.getShareName());
        assertEquals(username, config.getUsername());
        assertEquals(password, config.getPassword());
        assertEquals(domain, config.getDomain());
        assertEquals(timeout, config.getTimeout());
    }

    @Test
    void testSetServerAddress() {
        config = new SMBConnectionConfig();
        String serverAddress = "10.0.0.1";

        config.setServerAddress(serverAddress);

        assertEquals(serverAddress, config.getServerAddress());
    }

    @Test
    void testSetShareName() {
        config = new SMBConnectionConfig();
        String shareName = "documents";

        config.setShareName(shareName);

        assertEquals(shareName, config.getShareName());
    }

    @Test
    void testSetUsername() {
        config = new SMBConnectionConfig();
        String username = "admin";

        config.setUsername(username);

        assertEquals(username, config.getUsername());
    }

    @Test
    void testSetPassword() {
        config = new SMBConnectionConfig();
        String password = "secret123";

        config.setPassword(password);

        assertEquals(password, config.getPassword());
    }

    @Test
    void testSetDomain() {
        config = new SMBConnectionConfig();
        String domain = "MYDOMAIN";

        config.setDomain(domain);

        assertEquals(domain, config.getDomain());
    }

    @Test
    void testSetTimeout() {
        config = new SMBConnectionConfig();
        Integer timeout = 45;

        config.setTimeout(timeout);

        assertEquals(timeout, config.getTimeout());
    }

    @Test
    void testGetSmbUrl() {
        config = new SMBConnectionConfig("192.168.1.100", "shared", "user", "pass");

        String expectedUrl = "smb://192.168.1.100/shared/";
        assertEquals(expectedUrl, config.getSmbUrl());
    }

    @Test
    void testGetDomainQualifiedUsernameWithDomain() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "TESTDOMAIN", 30);

        String expected = "TESTDOMAIN\\user";
        assertEquals(expected, config.getDomainQualifiedUsername());
    }

    @Test
    void testGetDomainQualifiedUsernameWithoutDomain() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", null, 30);

        assertEquals("user", config.getDomainQualifiedUsername());
    }

    @Test
    void testGetDomainQualifiedUsernameWithEmptyDomain() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "", 30);

        assertEquals("user", config.getDomainQualifiedUsername());
    }

    @Test
    void testGetDomainQualifiedUsernameWithWhitespaceDomain() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "   ", 30);

        assertEquals("user", config.getDomainQualifiedUsername());
    }

    @Test
    void testIsValidWithAllFields() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "domain", 30);

        assertTrue(config.isValid());
    }

    @Test
    void testIsValidWithMissingServerAddress() {
        config = new SMBConnectionConfig(null, "share", "user", "pass", "domain", 30);

        assertFalse(config.isValid());
    }

    @Test
    void testIsValidWithEmptyServerAddress() {
        config = new SMBConnectionConfig("", "share", "user", "pass", "domain", 30);

        assertFalse(config.isValid());
    }

    @Test
    void testIsValidWithWhitespaceServerAddress() {
        config = new SMBConnectionConfig("   ", "share", "user", "pass", "domain", 30);

        assertFalse(config.isValid());
    }

    @Test
    void testIsValidWithMissingShareName() {
        config = new SMBConnectionConfig("server", null, "user", "pass", "domain", 30);

        assertFalse(config.isValid());
    }

    @Test
    void testIsValidWithMissingUsername() {
        config = new SMBConnectionConfig("server", "share", null, "pass", "domain", 30);

        assertFalse(config.isValid());
    }

    @Test
    void testIsValidWithMissingPassword() {
        config = new SMBConnectionConfig("server", "share", "user", null, "domain", 30);

        assertFalse(config.isValid());
    }

    @Test
    void testIsValidWithMissingDomain() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", null, 30);

        assertFalse(config.isValid());
    }

    @Test
    void testIsValidWithZeroTimeout() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "domain", 0);

        assertFalse(config.isValid());
    }

    @Test
    void testIsValidWithNegativeTimeout() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "domain", -1);

        assertFalse(config.isValid());
    }

    @Test
    void testIsValidWithNullTimeout() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "domain", null);

        assertFalse(config.isValid());
    }

    @Test
    void testValidationWithValidConfig() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "domain", 30);

        Set<ConstraintViolation<SMBConnectionConfig>> violations = validator.validate(config);

        assertTrue(violations.isEmpty());
    }

    @Test
    void testValidationWithBlankServerAddress() {
        config = new SMBConnectionConfig("", "share", "user", "pass", "domain", 30);

        Set<ConstraintViolation<SMBConnectionConfig>> violations = validator.validate(config);

        assertEquals(1, violations.size());
        ConstraintViolation<SMBConnectionConfig> violation = violations.iterator().next();
        assertEquals("Server address is required", violation.getMessage());
        assertEquals("serverAddress", violation.getPropertyPath().toString());
    }

    @Test
    void testValidationWithBlankShareName() {
        config = new SMBConnectionConfig("server", "", "user", "pass", "domain", 30);

        Set<ConstraintViolation<SMBConnectionConfig>> violations = validator.validate(config);

        assertEquals(1, violations.size());
        ConstraintViolation<SMBConnectionConfig> violation = violations.iterator().next();
        assertEquals("Share name is required", violation.getMessage());
        assertEquals("shareName", violation.getPropertyPath().toString());
    }

    @Test
    void testValidationWithBlankUsername() {
        config = new SMBConnectionConfig("server", "share", "", "pass", "domain", 30);

        Set<ConstraintViolation<SMBConnectionConfig>> violations = validator.validate(config);

        assertEquals(1, violations.size());
        ConstraintViolation<SMBConnectionConfig> violation = violations.iterator().next();
        assertEquals("Username is required", violation.getMessage());
        assertEquals("username", violation.getPropertyPath().toString());
    }

    @Test
    void testValidationWithBlankPassword() {
        config = new SMBConnectionConfig("server", "share", "user", "", "domain", 30);

        Set<ConstraintViolation<SMBConnectionConfig>> violations = validator.validate(config);

        assertEquals(1, violations.size());
        ConstraintViolation<SMBConnectionConfig> violation = violations.iterator().next();
        assertEquals("Password is required", violation.getMessage());
        assertEquals("password", violation.getPropertyPath().toString());
    }

    @Test
    void testValidationWithBlankDomain() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "", 30);

        Set<ConstraintViolation<SMBConnectionConfig>> violations = validator.validate(config);

        assertEquals(1, violations.size());
        ConstraintViolation<SMBConnectionConfig> violation = violations.iterator().next();
        assertEquals("Domain is required", violation.getMessage());
        assertEquals("domain", violation.getPropertyPath().toString());
    }

    @Test
    void testValidationWithNullTimeout() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "domain", null);

        Set<ConstraintViolation<SMBConnectionConfig>> violations = validator.validate(config);

        assertEquals(1, violations.size());
        ConstraintViolation<SMBConnectionConfig> violation = violations.iterator().next();
        assertEquals("Timeout is required", violation.getMessage());
        assertEquals("timeout", violation.getPropertyPath().toString());
    }

    @Test
    void testValidationWithZeroTimeout() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "domain", 0);

        Set<ConstraintViolation<SMBConnectionConfig>> violations = validator.validate(config);

        assertEquals(1, violations.size());
        ConstraintViolation<SMBConnectionConfig> violation = violations.iterator().next();
        assertEquals("Timeout must be at least 1 second", violation.getMessage());
        assertEquals("timeout", violation.getPropertyPath().toString());
    }

    @Test
    void testValidationWithMultipleViolations() {
        config = new SMBConnectionConfig("", "", "", "", "", 0);

        Set<ConstraintViolation<SMBConnectionConfig>> violations = validator.validate(config);

        assertEquals(6, violations.size()); // All fields should have violations
    }

    @Test
    void testEquals() {
        SMBConnectionConfig config1 = new SMBConnectionConfig("server", "share", "user", "pass", "domain", 30);
        SMBConnectionConfig config2 = new SMBConnectionConfig("server", "share", "user", "pass", "domain", 30);

        assertEquals(config1, config2);
    }

    @Test
    void testNotEquals() {
        SMBConnectionConfig config1 = new SMBConnectionConfig("server1", "share", "user", "pass", "domain", 30);
        SMBConnectionConfig config2 = new SMBConnectionConfig("server2", "share", "user", "pass", "domain", 30);

        assertNotEquals(config1, config2);
    }

    @Test
    void testHashCode() {
        SMBConnectionConfig config1 = new SMBConnectionConfig("server", "share", "user", "pass", "domain", 30);
        SMBConnectionConfig config2 = new SMBConnectionConfig("server", "share", "user", "pass", "domain", 30);

        assertEquals(config1.hashCode(), config2.hashCode());
    }

    @Test
    void testToString() {
        config = new SMBConnectionConfig("server", "share", "user", "pass", "domain", 30);
        String result = config.toString();

        assertTrue(result.contains("SMBConnectionConfig{"));
        assertTrue(result.contains("server"));
        assertTrue(result.contains("share"));
        assertTrue(result.contains("user"));
        assertTrue(result.contains("[PROTECTED]")); // Password should be masked
        assertTrue(result.contains("domain"));
        assertTrue(result.contains("30"));
        assertFalse(result.contains("password='pass'")); // Actual password value should not appear
    }

    @Test
    void testToStringDoesNotExposePassword() {
        config = new SMBConnectionConfig("server", "share", "user", "secretpassword", "domain", 30);
        String result = config.toString();

        assertFalse(result.contains("secretpassword"));
        assertTrue(result.contains("[PROTECTED]"));
    }
}