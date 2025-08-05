package com.example.scheduledfilewriter.config;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.integration.smb.session.SmbSessionFactory;

/**
 * Test configuration for SMB integration tests.
 * This configuration overrides the main SMB session factory to use local test
 * parameters.
 */
@TestConfiguration
public class TestSmbConfiguration {

    /**
     * Creates a test SMB session factory configured for local Samba server.
     * 
     * Parameters:
     * - Host: localhost
     * - Port: 1445
     * - Share: fileshare
     * - Username: testuser
     * - Password: testpass123
     */
    @Bean
    @Primary
    public SmbSessionFactory testSmbSessionFactory() {
        SmbSessionFactory sessionFactory = new SmbSessionFactory();

        // Configure for local test Samba server
        sessionFactory.setHost("localhost");
        sessionFactory.setPort(1445);
        sessionFactory.setShareAndDir("fileshare");
        sessionFactory.setUsername("testuser");
        sessionFactory.setPassword("testpass123");
        sessionFactory.setDomain(""); // Empty domain for local test

        System.out.println("🔧 Test SMB Session Factory configured:");
        System.out.println("  - Host: localhost");
        System.out.println("  - Port: 1445");
        System.out.println("  - Share: fileshare");
        System.out.println("  - Username: testuser");

        return sessionFactory;
    }
}