package com.example.scheduledfilewriter.service;

import com.example.scheduledfilewriter.model.SMBConnectionConfig;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests for ConfigurationService with actual Spring Boot property
 * injection.
 */
@SpringBootTest
@TestPropertySource(properties = {
        "spring.profiles.active=test",
        "FILE_SHARE_HOST=test-host.example.com",
        "FILE_SHARE_PATH=/test/share/path",
        "SMB_USERNAME=testuser",
        "SMB_PASSWORD=testpassword",
        "SMB_DOMAIN=TESTDOMAIN",
        "CONNECTION_TIMEOUT=45"
})
class ConfigurationServiceIntegrationTest {

    @Autowired
    private ConfigurationService configurationService;

    @Test
    void testGetFileShareHostWithProperties() {
        // When
        String host = configurationService.getFileShareHost();

        // Then
        assertEquals("test-host.example.com", host);
    }

    @Test
    void testGetFileSharePathWithProperties() {
        // When
        String path = configurationService.getFileSharePath();

        // Then
        assertEquals("/test/share/path", path);
    }

    @Test
    void testGetFileShareCredentialsWithProperties() {
        // When
        SMBConnectionConfig credentials = configurationService.getFileShareCredentials();

        // Then
        assertNotNull(credentials);
        assertEquals("testuser", credentials.getUsername());
        assertEquals("testpassword", credentials.getPassword());
        assertEquals("TESTDOMAIN", credentials.getDomain());
    }

    @Test
    void testGetConnectionSettingsWithProperties() {
        // When
        SMBConnectionConfig settings = configurationService.getConnectionSettings();

        // Then
        assertNotNull(settings);
        assertEquals("test-host.example.com", settings.getServerAddress());
        assertEquals("/test/share/path", settings.getShareName());
        assertEquals("testuser", settings.getUsername());
        assertEquals("testpassword", settings.getPassword());
        assertEquals("TESTDOMAIN", settings.getDomain());
        assertEquals(45, settings.getTimeout());
    }

    @Test
    void testGetConnectionTimeoutWithProperties() {
        // When
        int timeout = configurationService.getConnectionTimeout();

        // Then
        assertEquals(45, timeout);
    }
}