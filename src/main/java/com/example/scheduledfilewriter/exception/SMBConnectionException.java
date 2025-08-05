package com.example.scheduledfilewriter.exception;

/**
 * Custom exception for SMB connection-related errors.
 * This exception is thrown when SMB connection establishment fails
 * or when connection-related operations encounter errors.
 */
public class SMBConnectionException extends RuntimeException {

    /**
     * Constructs a new SMBConnectionException with the specified detail message.
     *
     * @param message the detail message explaining the SMB connection error
     */
    public SMBConnectionException(String message) {
        super(message);
    }

    /**
     * Constructs a new SMBConnectionException with the specified detail message and
     * cause.
     *
     * @param message the detail message explaining the SMB connection error
     * @param cause   the cause of the SMB connection error
     */
    public SMBConnectionException(String message, Throwable cause) {
        super(message, cause);
    }
}