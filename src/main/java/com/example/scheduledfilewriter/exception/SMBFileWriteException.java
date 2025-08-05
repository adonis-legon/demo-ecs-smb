package com.example.scheduledfilewriter.exception;

/**
 * Custom exception for SMB file writing errors.
 * This exception is thrown when file writing operations to SMB share fail.
 */
public class SMBFileWriteException extends RuntimeException {

    /**
     * Constructs a new SMBFileWriteException with the specified detail message.
     *
     * @param message the detail message explaining the file write error
     */
    public SMBFileWriteException(String message) {
        super(message);
    }

    /**
     * Constructs a new SMBFileWriteException with the specified detail message and
     * cause.
     *
     * @param message the detail message explaining the file write error
     * @param cause   the cause of the file write error
     */
    public SMBFileWriteException(String message, Throwable cause) {
        super(message, cause);
    }
}