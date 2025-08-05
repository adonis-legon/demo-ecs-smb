package com.example.scheduledfilewriter.service;

import com.example.scheduledfilewriter.model.SMBConnectionConfig;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for FileWriterService using Spring Integration SMB.
 * Note: These are basic tests that don't require SMB connectivity.
 */
class FileWriterServiceTest {

    private FileWriterService fileWriterService;
    private SMBConnectionConfig validConfig;

    @BeforeEach
    void setUp() {
        fileWriterService = new FileWriterService();
        validConfig = new SMBConnectionConfig("testhost", "testshare", "testuser", "testpass");

        // Set test properties
        ReflectionTestUtils.setField(fileWriterService, "targetFileCount", 2);
        ReflectionTestUtils.setField(fileWriterService, "minFileSize", 100);
        ReflectionTestUtils.setField(fileWriterService, "maxFileSize", 200);
    }

    @Test
    void testGetTargetFileCount() {
        // Act & Assert
        assertEquals(2, fileWriterService.getTargetFileCount());
    }

    @Test
    void testServiceInstantiation() {
        // Test that the service can be instantiated
        assertNotNull(fileWriterService);
    }

    @Test
    void testConfigValidation() {
        // Test that valid config is accepted
        assertNotNull(validConfig);
        assertEquals("testhost", validConfig.getServerAddress());
        assertEquals("testshare", validConfig.getShareName());
        assertEquals("testuser", validConfig.getUsername());
        assertEquals("testpass", validConfig.getPassword());
    }
}