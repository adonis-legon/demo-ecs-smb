package com.example.scheduledfilewriter.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.integration.smb.session.SmbSessionFactory;

/**
 * Configuration class for Spring Integration SMB support.
 * This class configures the SMB session factory for connecting to SMB/CIFS
 * shares.
 */
@Configuration
public class SmbIntegrationConfig {

    @Value("${smb.host:localhost}")
    private String host;

    @Value("${smb.port:445}")
    private int port;

    @Value("${smb.domain:WORKGROUP}")
    private String domain;

    @Value("${smb.username:testuser}")
    private String username;

    @Value("${smb.password:testpass123}")
    private String password;

    @Value("${smb.share:fileshare}")
    private String share;

    /**
     * Creates and configures the SMB session factory.
     * This factory is used by Spring Integration SMB components to establish
     * connections.
     *
     * @return configured SmbSessionFactory
     */
    @Bean
    public SmbSessionFactory smbSessionFactory() {
        // Log configuration values (mask password for security)
        System.out.println("SMB Configuration:");
        System.out.println("  Host: " + host);
        System.out.println("  Port: " + port);
        System.out.println("  Domain: " + domain);
        System.out.println("  Username: " + username);
        System.out.println("  Password: " + (password != null ? "[MASKED]" : "null"));
        System.out.println("  Share: " + share);

        SmbSessionFactory sessionFactory = new SmbSessionFactory();
        sessionFactory.setHost(host);
        sessionFactory.setPort(port);
        sessionFactory.setDomain(domain);
        sessionFactory.setUsername(username);
        sessionFactory.setPassword(password);
        sessionFactory.setShareAndDir(share);

        // Configure SMB protocol versions for better compatibility
        // Note: These will be set to reasonable defaults if the specific enum values
        // are not available

        System.out.println("SMB SessionFactory configured successfully");
        return sessionFactory;
    }
}