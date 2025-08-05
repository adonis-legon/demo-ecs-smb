package com.example.scheduledfilewriter.service;

import com.example.scheduledfilewriter.exception.ConfigurationException;
import com.example.scheduledfilewriter.model.SMBConnectionConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.util.ArrayList;
import java.util.List;

/**
 * Service for managing application configuration from environment variables.
 * This service retrieves configuration values that are populated by the ECS
 * task definition
 * from SSM Parameter Store and Secrets Manager.
 */
@Service
public class ConfigurationService {

    private static final Logger logger = LoggerFactory.getLogger(ConfigurationService.class);

    @Value("${FILE_SHARE_HOST:}")
    private String fileShareHost;

    @Value("${FILE_SHARE_PATH:}")
    private String fileSharePath;

    @Value("${SMB_USERNAME:}")
    private String smbUsername;

    @Value("${SMB_PASSWORD:}")
    private String smbPassword;

    @Value("${SMB_DOMAIN:}")
    private String smbDomain;

    @Value("${CONNECTION_TIMEOUT:30}")
    private int connectionTimeout;

    /**
     * Retrieves the file share host address.
     * 
     * @return the file share host address from environment variables
     */
    public String getFileShareHost() {
        logger.debug("Retrieved file share host: {}", fileShareHost);
        return fileShareHost;
    }

    /**
     * Retrieves the file share path where files should be written.
     * 
     * @return the file share path from environment variables
     */
    public String getFileSharePath() {
        logger.debug("Retrieved file share path: {}", fileSharePath);
        return fileSharePath;
    }

    /**
     * Retrieves SMB connection credentials from environment variables.
     * These credentials are sourced from AWS Secrets Manager via ECS task
     * definition.
     * 
     * @return SMBConnectionConfig containing username and password
     */
    public SMBConnectionConfig getFileShareCredentials() {
        logger.debug("Retrieved SMB credentials for user: {}", smbUsername);

        SMBConnectionConfig config = new SMBConnectionConfig();
        config.setUsername(smbUsername);
        config.setPassword(smbPassword);
        config.setDomain(smbDomain);

        return config;
    }

    /**
     * Retrieves SMB connection settings including host, path, and timeout.
     * These settings are sourced from SSM Parameter Store via ECS task definition.
     * 
     * @return SMBConnectionConfig containing connection parameters
     */
    public SMBConnectionConfig getConnectionSettings() {
        logger.debug("Retrieved connection settings - Host: {}, Path: {}, Timeout: {}s",
                fileShareHost, fileSharePath, connectionTimeout);

        SMBConnectionConfig config = new SMBConnectionConfig();
        config.setServerAddress(fileShareHost);
        config.setShareName(fileSharePath);
        config.setTimeout(connectionTimeout);
        config.setUsername(smbUsername);
        config.setPassword(smbPassword);
        config.setDomain(smbDomain);

        return config;
    }

    /**
     * Gets the SMB username from environment variables.
     * 
     * @return the SMB username
     */
    public String getSmbUsername() {
        return smbUsername;
    }

    /**
     * Gets the SMB password from environment variables.
     * 
     * @return the SMB password
     */
    public String getSmbPassword() {
        return smbPassword;
    }

    /**
     * Gets the SMB domain from environment variables.
     * 
     * @return the SMB domain
     */
    public String getSmbDomain() {
        return smbDomain;
    }

    /**
     * Gets the connection timeout value.
     * 
     * @return the connection timeout in seconds
     */
    public int getConnectionTimeout() {
        return connectionTimeout;
    }

    /**
     * Validates all required configuration parameters at startup.
     * This method is called automatically after bean construction to fail fast
     * if any required configuration is missing.
     * 
     * @throws ConfigurationException if any required configuration is missing or
     *                                invalid
     */
    @PostConstruct
    public void validateConfiguration() {
        logger.info("Validating application configuration...");

        List<String> missingParameters = new ArrayList<>();

        if (isNullOrEmpty(fileShareHost)) {
            missingParameters.add("FILE_SHARE_HOST");
        }

        if (isNullOrEmpty(fileSharePath)) {
            missingParameters.add("FILE_SHARE_PATH");
        }

        if (isNullOrEmpty(smbUsername)) {
            missingParameters.add("SMB_USERNAME");
        }

        if (isNullOrEmpty(smbPassword)) {
            missingParameters.add("SMB_PASSWORD");
        }

        // SMB_DOMAIN can be empty for local testing scenarios
        if (smbDomain == null) {
            missingParameters.add("SMB_DOMAIN");
        }

        if (connectionTimeout <= 0) {
            missingParameters.add("CONNECTION_TIMEOUT (must be positive)");
        }

        if (!missingParameters.isEmpty()) {
            String errorMessage = "Missing or invalid required configuration parameters: " +
                    String.join(", ", missingParameters);
            logger.error(errorMessage);
            throw new ConfigurationException(errorMessage);
        }

        logger.info("Configuration validation completed successfully");
    }

    /**
     * Validates that all required configuration parameters are present and valid.
     * This method can be called manually to check configuration validity.
     * 
     * @throws ConfigurationException if any required configuration is missing or
     *                                invalid
     */
    public void validateRequiredParameters() {
        validateConfiguration();
    }

    /**
     * Checks if a string is null or empty (including whitespace-only strings).
     * 
     * @param value the string to check
     * @return true if the string is null, empty, or contains only whitespace
     */
    private boolean isNullOrEmpty(String value) {
        return value == null || value.trim().isEmpty();
    }

    /**
     * Validates SMB connection configuration parameters.
     * 
     * @param config the SMB connection configuration to validate
     * @throws ConfigurationException if the configuration is invalid
     */
    public void validateSMBConnectionConfig(SMBConnectionConfig config) {
        if (config == null) {
            throw new ConfigurationException("SMB connection configuration cannot be null");
        }

        List<String> errors = new ArrayList<>();

        if (isNullOrEmpty(config.getServerAddress())) {
            errors.add("Server address is required");
        }

        if (isNullOrEmpty(config.getShareName())) {
            errors.add("Share name is required");
        }

        if (isNullOrEmpty(config.getUsername())) {
            errors.add("Username is required");
        }

        if (isNullOrEmpty(config.getPassword())) {
            errors.add("Password is required");
        }

        if (config.getTimeout() <= 0) {
            errors.add("Timeout must be positive");
        }

        if (!errors.isEmpty()) {
            String errorMessage = "Invalid SMB connection configuration: " + String.join(", ", errors);
            logger.error(errorMessage);
            throw new ConfigurationException(errorMessage);
        }
    }
}