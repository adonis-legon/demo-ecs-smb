package com.example.scheduledfilewriter.util;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for the LoggingContext utility class.
 * Tests correlation ID generation, MDC management, and structured logging
 * functionality.
 */
class LoggingContextTest {

    @BeforeEach
    void setUp() {
        // Clear MDC before each test
        MDC.clear();
    }

    @AfterEach
    void tearDown() {
        // Clear MDC after each test
        MDC.clear();
    }

    @Test
    void testGenerateCorrelationId() {
        // Act
        String correlationId1 = LoggingContext.generateCorrelationId();
        String correlationId2 = LoggingContext.generateCorrelationId();

        // Assert
        assertNotNull(correlationId1);
        assertNotNull(correlationId2);
        assertTrue(correlationId1.startsWith("corr_"));
        assertTrue(correlationId2.startsWith("corr_"));
        assertNotEquals(correlationId1, correlationId2);
        assertEquals(13, correlationId1.length()); // "corr_" + 8 characters
    }

    @Test
    void testGenerateExecutionId() {
        // Act
        String executionId1 = LoggingContext.generateExecutionId();

        // Add a small delay to ensure different timestamps
        try {
            Thread.sleep(2); // 2ms delay to ensure different millisecond timestamps
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        String executionId2 = LoggingContext.generateExecutionId();

        // Assert
        assertNotNull(executionId1);
        assertNotNull(executionId2);
        assertTrue(executionId1.startsWith("exec_"));
        assertTrue(executionId2.startsWith("exec_"));
        // Execution IDs should be different due to timestamp differences
        assertNotEquals(executionId1, executionId2);
    }

    @Test
    void testSetupExecutionContext() {
        // Arrange
        String executionId = "test_exec_123";

        // Act
        String correlationId = LoggingContext.setupExecutionContext(executionId);

        // Assert
        assertNotNull(correlationId);
        assertTrue(correlationId.startsWith("corr_"));
        assertEquals(correlationId, MDC.get(LoggingContext.CORRELATION_ID));
        assertEquals(executionId, MDC.get(LoggingContext.EXECUTION_ID));
    }

    @Test
    void testSetOperation() {
        // Arrange
        String operation = "test_operation";

        // Act
        LoggingContext.setOperation(operation);

        // Assert
        assertEquals(operation, MDC.get(LoggingContext.OPERATION));
    }

    @Test
    void testSetDuration() {
        // Arrange
        long duration = 1500L;

        // Act
        LoggingContext.setDuration(duration);

        // Assert
        assertEquals("1500", MDC.get(LoggingContext.DURATION));
    }

    @Test
    void testSetFileCount() {
        // Arrange
        int fileCount = 10;

        // Act
        LoggingContext.setFileCount(fileCount);

        // Assert
        assertEquals("10", MDC.get(LoggingContext.FILE_COUNT));
    }

    @Test
    void testSetConnectionStatus() {
        // Arrange
        String status = "CONNECTED";

        // Act
        LoggingContext.setConnectionStatus(status);

        // Assert
        assertEquals(status, MDC.get(LoggingContext.CONNECTION_STATUS));
    }

    @Test
    void testSetErrorType() {
        // Arrange
        String errorType = "CONNECTION_ERROR";

        // Act
        LoggingContext.setErrorType(errorType);

        // Assert
        assertEquals(errorType, MDC.get(LoggingContext.ERROR_TYPE));
    }

    @Test
    void testClearKey() {
        // Arrange
        LoggingContext.setOperation("test_operation");
        LoggingContext.setDuration(1000L);

        // Act
        LoggingContext.clearKey(LoggingContext.OPERATION);

        // Assert
        assertNull(MDC.get(LoggingContext.OPERATION));
        assertEquals("1000", MDC.get(LoggingContext.DURATION)); // Should still be present
    }

    @Test
    void testClearOperationContext() {
        // Arrange
        LoggingContext.setupExecutionContext("test_exec");
        LoggingContext.setOperation("test_operation");
        LoggingContext.setDuration(1000L);
        LoggingContext.setFileCount(5);
        LoggingContext.setConnectionStatus("CONNECTED");
        LoggingContext.setErrorType("TEST_ERROR");

        // Act
        LoggingContext.clearOperationContext();

        // Assert
        // Execution context should remain
        assertNotNull(MDC.get(LoggingContext.CORRELATION_ID));
        assertNotNull(MDC.get(LoggingContext.EXECUTION_ID));

        // Operation context should be cleared
        assertNull(MDC.get(LoggingContext.OPERATION));
        assertNull(MDC.get(LoggingContext.DURATION));
        assertNull(MDC.get(LoggingContext.FILE_COUNT));
        assertNull(MDC.get(LoggingContext.CONNECTION_STATUS));
        assertNull(MDC.get(LoggingContext.ERROR_TYPE));
    }

    @Test
    void testClearAll() {
        // Arrange
        LoggingContext.setupExecutionContext("test_exec");
        LoggingContext.setOperation("test_operation");
        LoggingContext.setDuration(1000L);

        // Act
        LoggingContext.clearAll();

        // Assert
        assertNull(MDC.get(LoggingContext.CORRELATION_ID));
        assertNull(MDC.get(LoggingContext.EXECUTION_ID));
        assertNull(MDC.get(LoggingContext.OPERATION));
        assertNull(MDC.get(LoggingContext.DURATION));
    }

    @Test
    void testGetCurrentCorrelationId() {
        // Arrange
        String correlationId = LoggingContext.setupExecutionContext("test_exec");

        // Act
        String retrieved = LoggingContext.getCurrentCorrelationId();

        // Assert
        assertEquals(correlationId, retrieved);
    }

    @Test
    void testGetCurrentExecutionId() {
        // Arrange
        String executionId = "test_exec_123";
        LoggingContext.setupExecutionContext(executionId);

        // Act
        String retrieved = LoggingContext.getCurrentExecutionId();

        // Assert
        assertEquals(executionId, retrieved);
    }

    @Test
    void testGetCurrentOperation() {
        // Arrange
        String operation = "test_operation";
        LoggingContext.setOperation(operation);

        // Act
        String retrieved = LoggingContext.getCurrentOperation();

        // Assert
        assertEquals(operation, retrieved);
    }

    @Test
    void testWithOperation() {
        // Arrange
        String operation = "test_operation";
        boolean[] executed = { false };

        // Act
        LoggingContext.withOperation(operation, () -> {
            executed[0] = true;
            assertEquals(operation, MDC.get(LoggingContext.OPERATION));
        });

        // Assert
        assertTrue(executed[0]);
        assertNull(MDC.get(LoggingContext.OPERATION)); // Should be cleared after execution
    }

    @Test
    void testWithTimedOperation() {
        // Arrange
        String operation = "test_operation";
        boolean[] executed = { false };

        // Act
        long duration = LoggingContext.withTimedOperation(operation, () -> {
            executed[0] = true;
            assertEquals(operation, MDC.get(LoggingContext.OPERATION));
            try {
                Thread.sleep(10); // Small delay to ensure measurable duration
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        // Assert
        assertTrue(executed[0]);
        assertTrue(duration >= 0);
        assertNull(MDC.get(LoggingContext.OPERATION)); // Should be cleared after execution
    }

    @Test
    void testCreatePerformanceMetrics() {
        // Arrange
        String operationName = "test_operation";
        long startTime = System.currentTimeMillis() - 1000; // 1 second ago
        int fileCount = 10;
        boolean success = true;

        // Act
        String metrics = LoggingContext.createPerformanceMetrics(operationName, startTime, fileCount, success);

        // Assert
        assertNotNull(metrics);
        assertTrue(metrics.contains(operationName));
        assertTrue(metrics.contains("duration="));
        assertTrue(metrics.contains("files=10"));
        assertTrue(metrics.contains("rate="));
        assertTrue(metrics.contains("success=true"));
    }

    @Test
    void testCreatePerformanceMetricsWithZeroFiles() {
        // Arrange
        String operationName = "test_operation";
        long startTime = System.currentTimeMillis() - 1000;
        int fileCount = 0;
        boolean success = false;

        // Act
        String metrics = LoggingContext.createPerformanceMetrics(operationName, startTime, fileCount, success);

        // Assert
        assertNotNull(metrics);
        assertTrue(metrics.contains("files=0"));
        assertTrue(metrics.contains("rate=0.00"));
        assertTrue(metrics.contains("success=false"));
    }

    @Test
    void testCreatePerformanceMetricsWithZeroDuration() {
        // Arrange
        String operationName = "test_operation";
        long startTime = System.currentTimeMillis(); // Current time (zero duration)
        int fileCount = 5;
        boolean success = true;

        // Act
        String metrics = LoggingContext.createPerformanceMetrics(operationName, startTime, fileCount, success);

        // Assert
        assertNotNull(metrics);
        assertTrue(metrics.contains("files=5"));
        assertTrue(metrics.contains("rate=0.00")); // Zero duration should result in 0 rate
    }

    @Test
    void testMDCKeysConstants() {
        // Assert that all expected constants are defined
        assertEquals("correlationId", LoggingContext.CORRELATION_ID);
        assertEquals("executionId", LoggingContext.EXECUTION_ID);
        assertEquals("operation", LoggingContext.OPERATION);
        assertEquals("duration", LoggingContext.DURATION);
        assertEquals("fileCount", LoggingContext.FILE_COUNT);
        assertEquals("connectionStatus", LoggingContext.CONNECTION_STATUS);
        assertEquals("errorType", LoggingContext.ERROR_TYPE);
    }
}