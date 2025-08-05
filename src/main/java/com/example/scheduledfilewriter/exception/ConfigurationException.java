package com.example.scheduledfilewriter.exception;

/**
 * Custom exception for configuration-related errors.
 * This exception is thrown when required configuration parameters are missing
 * or invalid during application startup.
 */
public class ConfigurationException extends RuntimeException {

    /**
     * Constructs a new ConfigurationException with the specified detail message.
     *
     * @param message the detail message explaining the configuration error
     */
    public ConfigurationException(String message) {
        super(message);
    }

    /**
     * Constructs a new ConfigurationException with the specified detail message and
     * cause.
     *
     * @param message the detail message explaining the configuration error
     * @param cause   the cause of the configuration error
     */
    public ConfigurationException(String message, Throwable cause) {
        super(message, cause);
    }
}