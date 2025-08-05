package com.example.scheduledfilewriter.service;

import com.example.scheduledfilewriter.config.TestSmbConfiguration;
import com.example.scheduledfilewriter.model.ExecutionResult;
import com.example.scheduledfilewriter.model.SMBConnectionConfig;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.integration.smb.session.SmbSessionFactory;
import org.springframework.test.context.TestPropertySource;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration test for FileWriterService using a local Samba server.
 * 
 * Prerequisites:
 * - Local Samba server running on localhost:1445
 * - Share: fileshare
 * - Username: testuser
 * - Password: testpass123
 */
@SpringBootTest
@Import(TestSmbConfiguration.class)
@TestPropertySource(properties = {
        "spring.profiles.active=test",
        "file.generation.count=3",
        "file.generation.size.min=100",
        "file.generation.size.max=500",
        "FILE_SHARE_HOST=localhost",
        "FILE_SHARE_PATH=fileshare",
        "SMB_USERNAME=testuser",
        "SMB_PASSWORD=testpass123",
        "SMB_DOMAIN=",
        "smb.host=localhost",
        "smb.port=1445",
        "smb.username=testuser",
        "smb.password=testpass123",
        "smb.domain=",
        "smb.share=fileshare"
})
class FileWriterServiceIntegrationTest {

    @Autowired
    private FileWriterService fileWriterService;

    @Autowired
    private SmbSessionFactory smbSessionFactory;

    private SMBConnectionConfig testConfig;
    private SmbSessionFactory testSessionFactory;

    @BeforeEach
    void setUp() {
        // Create test configuration for local Samba server
        testConfig = new SMBConnectionConfig();
        testConfig.setServerAddress("localhost");
        testConfig.setShareName("fileshare");
        testConfig.setUsername("testuser");
        testConfig.setPassword("testpass123");
        testConfig.setDomain(""); // Empty domain for local test
        testConfig.setTimeout(30);

        // Create test session factory
        testSessionFactory = new SmbSessionFactory();
        testSessionFactory.setHost("localhost");
        testSessionFactory.setPort(1445);
        testSessionFactory.setShareAndDir("fileshare");
        testSessionFactory.setUsername("testuser");
        testSessionFactory.setPassword("testpass123");
        testSessionFactory.setDomain("");
    }

    @Test
    void testSmbConnectionEstablishment() {
        // Test that we can establish a connection to the local Samba server
        assertDoesNotThrow(() -> {
            try (var session = smbSessionFactory.getSession()) {
                assertNotNull(session, "SMB session should not be null");
                System.out.println("✅ SMB connection established successfully");
            }
        }, "Should be able to establish SMB connection");
    }

    @Test
    void testFileWriterServiceWithLocalSamba() {
        // Test the FileWriterService with the local Samba server
        System.out.println("🧪 Testing FileWriterService with local Samba server...");

        ExecutionResult result = assertDoesNotThrow(() -> fileWriterService.generateAndWriteFiles(testConfig),
                "FileWriterService should not throw exception");

        assertNotNull(result, "Execution result should not be null");

        // Print results for debugging
        System.out.println("📊 Test Results:");
        System.out.println("  - Status: " + result.getStatus());
        System.out.println("  - Files created: " + result.getCreatedFiles().size());
        System.out.println("  - Target file count: " + fileWriterService.getTargetFileCount());

        if (!result.getCreatedFiles().isEmpty()) {
            System.out.println("  - Successful files:");
            result.getCreatedFiles().forEach(file -> System.out.println("    ✅ " + file));
        }

        // Assertions
        assertTrue(result.getCreatedFiles().size() > 0,
                "At least one file should be written successfully");
        assertEquals("SUCCESS", result.getStatus(),
                "Operation should complete successfully");
        assertEquals(3, result.getCreatedFiles().size(),
                "Should create exactly 3 files as configured");
    }

    @Test
    void testSmbSessionFactoryConfiguration() {
        // Test that the session factory is configured correctly
        assertEquals("localhost", testSessionFactory.getHost());
        assertEquals(1445, testSessionFactory.getPort());
        assertEquals("fileshare", testSessionFactory.getShareAndDir());
        assertEquals("testuser", testSessionFactory.getUsername());
        assertEquals("testpass123", testSessionFactory.getPassword());

        System.out.println("✅ SMB Session Factory configuration is correct");
    }

    @Test
    void testConnectionConfigurationMapping() {
        // Test that our SMBConnectionConfig maps correctly to SmbSessionFactory
        SmbSessionFactory factory = new SmbSessionFactory();
        factory.setHost(testConfig.getServerAddress());
        factory.setPort(1445); // Use hardcoded port since SMBConnectionConfig doesn't have port field
        factory.setShareAndDir(testConfig.getShareName());
        factory.setUsername(testConfig.getUsername());
        factory.setPassword(testConfig.getPassword());
        factory.setDomain(testConfig.getDomain());

        // Test connection with mapped configuration
        assertDoesNotThrow(() -> {
            try (var session = factory.getSession()) {
                assertNotNull(session);
                System.out.println("✅ Configuration mapping works correctly");
            }
        });
    }
}