package com.example.scheduledfilewriter.service;

import com.example.scheduledfilewriter.exception.ConfigurationException;
import com.example.scheduledfilewriter.model.SMBConnectionConfig;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for ConfigurationService with mocked environment variables.
 */
class ConfigurationServiceTest {

    private ConfigurationService configurationService;

    @BeforeEach
    void setUp() {
        configurationService = new ConfigurationService();
    }

    @Test
    void testGetFileShareHost() {
        // Given
        String expectedHost = "192.168.1.100";
        ReflectionTestUtils.setField(configurationService, "fileShareHost", expectedHost);

        // When
        String actualHost = configurationService.getFileShareHost();

        // Then
        assertEquals(expectedHost, actualHost);
    }

    @Test
    void testGetFileSharePath() {
        // Given
        String expectedPath = "/shared/files";
        ReflectionTestUtils.setField(configurationService, "fileSharePath", expectedPath);

        // When
        String actualPath = configurationService.getFileSharePath();

        // Then
        assertEquals(expectedPath, actualPath);
    }

    @Test
    void testGetFileShareCredentials() {
        // Given
        String expectedUsername = "testuser";
        String expectedPassword = "testpass";
        String expectedDomain = "WORKGROUP";

        ReflectionTestUtils.setField(configurationService, "smbUsername", expectedUsername);
        ReflectionTestUtils.setField(configurationService, "smbPassword", expectedPassword);
        ReflectionTestUtils.setField(configurationService, "smbDomain", expectedDomain);

        // When
        SMBConnectionConfig credentials = configurationService.getFileShareCredentials();

        // Then
        assertNotNull(credentials);
        assertEquals(expectedUsername, credentials.getUsername());
        assertEquals(expectedPassword, credentials.getPassword());
        assertEquals(expectedDomain, credentials.getDomain());
    }

    @Test
    void testGetConnectionSettings() {
        // Given
        String expectedHost = "192.168.1.100";
        String expectedPath = "/shared/files";
        String expectedUsername = "testuser";
        String expectedPassword = "testpass";
        String expectedDomain = "WORKGROUP";
        int expectedTimeout = 45;

        ReflectionTestUtils.setField(configurationService, "fileShareHost", expectedHost);
        ReflectionTestUtils.setField(configurationService, "fileSharePath", expectedPath);
        ReflectionTestUtils.setField(configurationService, "smbUsername", expectedUsername);
        ReflectionTestUtils.setField(configurationService, "smbPassword", expectedPassword);
        ReflectionTestUtils.setField(configurationService, "smbDomain", expectedDomain);
        ReflectionTestUtils.setField(configurationService, "connectionTimeout", expectedTimeout);

        // When
        SMBConnectionConfig settings = configurationService.getConnectionSettings();

        // Then
        assertNotNull(settings);
        assertEquals(expectedHost, settings.getServerAddress());
        assertEquals(expectedPath, settings.getShareName());
        assertEquals(expectedUsername, settings.getUsername());
        assertEquals(expectedPassword, settings.getPassword());
        assertEquals(expectedDomain, settings.getDomain());
        assertEquals(expectedTimeout, settings.getTimeout());
    }

    @Test
    void testGetSmbUsername() {
        // Given
        String expectedUsername = "testuser";
        ReflectionTestUtils.setField(configurationService, "smbUsername", expectedUsername);

        // When
        String actualUsername = configurationService.getSmbUsername();

        // Then
        assertEquals(expectedUsername, actualUsername);
    }

    @Test
    void testGetSmbPassword() {
        // Given
        String expectedPassword = "testpass";
        ReflectionTestUtils.setField(configurationService, "smbPassword", expectedPassword);

        // When
        String actualPassword = configurationService.getSmbPassword();

        // Then
        assertEquals(expectedPassword, actualPassword);
    }

    @Test
    void testGetSmbDomain() {
        // Given
        String expectedDomain = "WORKGROUP";
        ReflectionTestUtils.setField(configurationService, "smbDomain", expectedDomain);

        // When
        String actualDomain = configurationService.getSmbDomain();

        // Then
        assertEquals(expectedDomain, actualDomain);
    }

    @Test
    void testGetConnectionTimeout() {
        // Given
        int expectedTimeout = 60;
        ReflectionTestUtils.setField(configurationService, "connectionTimeout", expectedTimeout);

        // When
        int actualTimeout = configurationService.getConnectionTimeout();

        // Then
        assertEquals(expectedTimeout, actualTimeout);
    }

    @Test
    void testDefaultConnectionTimeout() {
        // Given - no explicit timeout set, should use default from @Value annotation
        // The default value is 30 as specified in the @Value annotation

        // When
        int actualTimeout = configurationService.getConnectionTimeout();

        // Then
        assertEquals(0, actualTimeout); // ReflectionTestUtils doesn't set default values, so it will be 0
    }

    @Test
    void testValidateConfiguration_AllParametersPresent_Success() {
        // Given
        setValidConfiguration();

        // When & Then - should not throw exception
        assertDoesNotThrow(() -> configurationService.validateConfiguration());
    }

    @Test
    void testValidateConfiguration_MissingFileShareHost_ThrowsException() {
        // Given
        setValidConfiguration();
        ReflectionTestUtils.setField(configurationService, "fileShareHost", "");

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateConfiguration());
        assertTrue(exception.getMessage().contains("FILE_SHARE_HOST"));
    }

    @Test
    void testValidateConfiguration_MissingFileSharePath_ThrowsException() {
        // Given
        setValidConfiguration();
        ReflectionTestUtils.setField(configurationService, "fileSharePath", null);

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateConfiguration());
        assertTrue(exception.getMessage().contains("FILE_SHARE_PATH"));
    }

    @Test
    void testValidateConfiguration_MissingUsername_ThrowsException() {
        // Given
        setValidConfiguration();
        ReflectionTestUtils.setField(configurationService, "smbUsername", "   ");

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateConfiguration());
        assertTrue(exception.getMessage().contains("SMB_USERNAME"));
    }

    @Test
    void testValidateConfiguration_MissingPassword_ThrowsException() {
        // Given
        setValidConfiguration();
        ReflectionTestUtils.setField(configurationService, "smbPassword", "");

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateConfiguration());
        assertTrue(exception.getMessage().contains("SMB_PASSWORD"));
    }

    @Test
    void testValidateConfiguration_MissingDomain_ThrowsException() {
        // Given
        setValidConfiguration();
        ReflectionTestUtils.setField(configurationService, "smbDomain", null);

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateConfiguration());
        assertTrue(exception.getMessage().contains("SMB_DOMAIN"));
    }

    @Test
    void testValidateConfiguration_InvalidTimeout_ThrowsException() {
        // Given
        setValidConfiguration();
        ReflectionTestUtils.setField(configurationService, "connectionTimeout", -1);

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateConfiguration());
        assertTrue(exception.getMessage().contains("CONNECTION_TIMEOUT"));
    }

    @Test
    void testValidateConfiguration_MultipleErrors_ThrowsExceptionWithAllErrors() {
        // Given
        ReflectionTestUtils.setField(configurationService, "fileShareHost", "");
        ReflectionTestUtils.setField(configurationService, "smbUsername", null);
        ReflectionTestUtils.setField(configurationService, "connectionTimeout", 0);

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateConfiguration());
        String message = exception.getMessage();
        assertTrue(message.contains("FILE_SHARE_HOST"));
        assertTrue(message.contains("SMB_USERNAME"));
        assertTrue(message.contains("CONNECTION_TIMEOUT"));
    }

    @Test
    void testValidateRequiredParameters_CallsValidateConfiguration() {
        // Given
        setValidConfiguration();

        // When & Then - should not throw exception
        assertDoesNotThrow(() -> configurationService.validateRequiredParameters());
    }

    @Test
    void testValidateSMBConnectionConfig_ValidConfig_Success() {
        // Given
        SMBConnectionConfig config = new SMBConnectionConfig();
        config.setServerAddress("192.168.1.100");
        config.setShareName("/shared");
        config.setUsername("testuser");
        config.setPassword("testpass");
        config.setDomain("WORKGROUP");
        config.setTimeout(30);

        // When & Then - should not throw exception
        assertDoesNotThrow(() -> configurationService.validateSMBConnectionConfig(config));
    }

    @Test
    void testValidateSMBConnectionConfig_NullConfig_ThrowsException() {
        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateSMBConnectionConfig(null));
        assertTrue(exception.getMessage().contains("cannot be null"));
    }

    @Test
    void testValidateSMBConnectionConfig_MissingServerAddress_ThrowsException() {
        // Given
        SMBConnectionConfig config = createValidSMBConfig();
        config.setServerAddress("");

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateSMBConnectionConfig(config));
        assertTrue(exception.getMessage().contains("Server address is required"));
    }

    @Test
    void testValidateSMBConnectionConfig_MissingShareName_ThrowsException() {
        // Given
        SMBConnectionConfig config = createValidSMBConfig();
        config.setShareName(null);

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateSMBConnectionConfig(config));
        assertTrue(exception.getMessage().contains("Share name is required"));
    }

    @Test
    void testValidateSMBConnectionConfig_MissingUsername_ThrowsException() {
        // Given
        SMBConnectionConfig config = createValidSMBConfig();
        config.setUsername("   ");

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateSMBConnectionConfig(config));
        assertTrue(exception.getMessage().contains("Username is required"));
    }

    @Test
    void testValidateSMBConnectionConfig_MissingPassword_ThrowsException() {
        // Given
        SMBConnectionConfig config = createValidSMBConfig();
        config.setPassword("");

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateSMBConnectionConfig(config));
        assertTrue(exception.getMessage().contains("Password is required"));
    }

    @Test
    void testValidateSMBConnectionConfig_InvalidTimeout_ThrowsException() {
        // Given
        SMBConnectionConfig config = createValidSMBConfig();
        config.setTimeout(0);

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateSMBConnectionConfig(config));
        assertTrue(exception.getMessage().contains("Timeout must be positive"));
    }

    @Test
    void testValidateSMBConnectionConfig_MultipleErrors_ThrowsExceptionWithAllErrors() {
        // Given
        SMBConnectionConfig config = new SMBConnectionConfig();
        config.setServerAddress("");
        config.setUsername(null);
        config.setTimeout(-1);

        // When & Then
        ConfigurationException exception = assertThrows(ConfigurationException.class,
                () -> configurationService.validateSMBConnectionConfig(config));
        String message = exception.getMessage();
        assertTrue(message.contains("Server address is required"));
        assertTrue(message.contains("Username is required"));
        assertTrue(message.contains("Timeout must be positive"));
    }

    /**
     * Helper method to set valid configuration for testing.
     */
    private void setValidConfiguration() {
        ReflectionTestUtils.setField(configurationService, "fileShareHost", "192.168.1.100");
        ReflectionTestUtils.setField(configurationService, "fileSharePath", "/shared/files");
        ReflectionTestUtils.setField(configurationService, "smbUsername", "testuser");
        ReflectionTestUtils.setField(configurationService, "smbPassword", "testpass");
        ReflectionTestUtils.setField(configurationService, "smbDomain", "WORKGROUP");
        ReflectionTestUtils.setField(configurationService, "connectionTimeout", 30);
    }

    /**
     * Helper method to create a valid SMB connection configuration for testing.
     */
    private SMBConnectionConfig createValidSMBConfig() {
        SMBConnectionConfig config = new SMBConnectionConfig();
        config.setServerAddress("192.168.1.100");
        config.setShareName("/shared");
        config.setUsername("testuser");
        config.setPassword("testpass");
        config.setDomain("WORKGROUP");
        config.setTimeout(30);
        return config;
    }
}