package com.example.scheduledfilewriter.util;

import org.slf4j.MDC;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

/**
 * Utility class for managing logging context and correlation IDs.
 * Provides methods to set up structured logging context for tracking
 * individual executions and operations.
 */
public class LoggingContext {

    // MDC keys for structured logging
    public static final String CORRELATION_ID = "correlationId";
    public static final String EXECUTION_ID = "executionId";
    public static final String OPERATION = "operation";
    public static final String DURATION = "duration";
    public static final String FILE_COUNT = "fileCount";
    public static final String CONNECTION_STATUS = "connectionStatus";
    public static final String ERROR_TYPE = "errorType";

    private static final DateTimeFormatter TIMESTAMP_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss_SSS");

    /**
     * Generates a new correlation ID for tracking requests.
     * 
     * @return a unique correlation ID
     */
    public static String generateCorrelationId() {
        return "corr_" + UUID.randomUUID().toString().substring(0, 8);
    }

    /**
     * Generates a new execution ID for tracking individual application runs.
     * 
     * @return a unique execution ID
     */
    public static String generateExecutionId() {
        return "exec_" + LocalDateTime.now().format(TIMESTAMP_FORMAT);
    }

    /**
     * Sets up the logging context for a new execution.
     * 
     * @param executionId the unique execution identifier
     * @return the correlation ID for this execution
     */
    public static String setupExecutionContext(String executionId) {
        String correlationId = generateCorrelationId();
        MDC.put(CORRELATION_ID, correlationId);
        MDC.put(EXECUTION_ID, executionId);
        return correlationId;
    }

    /**
     * Sets the current operation in the logging context.
     * 
     * @param operation the operation being performed
     */
    public static void setOperation(String operation) {
        MDC.put(OPERATION, operation);
    }

    /**
     * Sets the duration of an operation in the logging context.
     * 
     * @param durationMs the duration in milliseconds
     */
    public static void setDuration(long durationMs) {
        MDC.put(DURATION, String.valueOf(durationMs));
    }

    /**
     * Sets the file count in the logging context.
     * 
     * @param count the number of files
     */
    public static void setFileCount(int count) {
        MDC.put(FILE_COUNT, String.valueOf(count));
    }

    /**
     * Sets the connection status in the logging context.
     * 
     * @param status the connection status (CONNECTED, DISCONNECTED, FAILED, etc.)
     */
    public static void setConnectionStatus(String status) {
        MDC.put(CONNECTION_STATUS, status);
    }

    /**
     * Sets the error type in the logging context.
     * 
     * @param errorType the type of error that occurred
     */
    public static void setErrorType(String errorType) {
        MDC.put(ERROR_TYPE, errorType);
    }

    /**
     * Sets the correlation ID in the logging context.
     * 
     * @param correlationId the correlation ID to set
     */
    public static void setCorrelationId(String correlationId) {
        MDC.put(CORRELATION_ID, correlationId);
    }

    /**
     * Clears all logging context (alias for clearAll).
     */
    public static void clear() {
        clearAll();
    }

    /**
     * Clears a specific key from the logging context.
     * 
     * @param key the MDC key to clear
     */
    public static void clearKey(String key) {
        MDC.remove(key);
    }

    /**
     * Clears all operation-specific context while keeping execution context.
     */
    public static void clearOperationContext() {
        MDC.remove(OPERATION);
        MDC.remove(DURATION);
        MDC.remove(FILE_COUNT);
        MDC.remove(CONNECTION_STATUS);
        MDC.remove(ERROR_TYPE);
    }

    /**
     * Clears all logging context.
     */
    public static void clearAll() {
        MDC.clear();
    }

    /**
     * Gets the current correlation ID from the logging context.
     * 
     * @return the current correlation ID or null if not set
     */
    public static String getCurrentCorrelationId() {
        return MDC.get(CORRELATION_ID);
    }

    /**
     * Gets the current execution ID from the logging context.
     * 
     * @return the current execution ID or null if not set
     */
    public static String getCurrentExecutionId() {
        return MDC.get(EXECUTION_ID);
    }

    /**
     * Gets the current operation from the logging context.
     * 
     * @return the current operation or null if not set
     */
    public static String getCurrentOperation() {
        return MDC.get(OPERATION);
    }

    /**
     * Utility method to execute an operation with logging context.
     * 
     * @param operation the operation name
     * @param runnable  the operation to execute
     */
    public static void withOperation(String operation, Runnable runnable) {
        setOperation(operation);
        try {
            runnable.run();
        } finally {
            clearKey(OPERATION);
        }
    }

    /**
     * Utility method to execute an operation with timing and logging context.
     * 
     * @param operation the operation name
     * @param runnable  the operation to execute
     * @return the duration in milliseconds
     */
    public static long withTimedOperation(String operation, Runnable runnable) {
        setOperation(operation);
        long startTime = System.currentTimeMillis();
        try {
            runnable.run();
            return System.currentTimeMillis() - startTime;
        } finally {
            long duration = System.currentTimeMillis() - startTime;
            setDuration(duration);
            clearKey(OPERATION);
        }
    }

    /**
     * Creates a performance metrics summary for logging.
     * 
     * @param operationName the name of the operation
     * @param startTime     the start time in milliseconds
     * @param fileCount     the number of files processed
     * @param success       whether the operation was successful
     * @return a formatted performance summary string
     */
    public static String createPerformanceMetrics(String operationName, long startTime, int fileCount,
            boolean success) {
        long duration = System.currentTimeMillis() - startTime;
        double filesPerSecond = fileCount > 0 && duration > 0 ? (fileCount * 1000.0) / duration : 0;

        return String.format("Performance metrics for %s: duration=%dms, files=%d, rate=%.2f files/sec, success=%s",
                operationName, duration, fileCount, filesPerSecond, success);
    }
}