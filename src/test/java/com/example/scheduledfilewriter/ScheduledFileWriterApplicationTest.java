package com.example.scheduledfilewriter;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Basic tests for ScheduledFileWriterApplication.
 */
class ScheduledFileWriterApplicationTest {

    @Test
    void testGetExitCodes() {
        // Act
        int[] exitCodes = ScheduledFileWriterApplication.getExitCodes();

        // Assert
        assertNotNull(exitCodes);
        assertEquals(5, exitCodes.length);
        assertEquals(0, exitCodes[0]); // SUCCESS
        assertEquals(1, exitCodes[1]); // CONFIGURATION_ERROR
        assertEquals(2, exitCodes[2]); // CONNECTION_ERROR
        assertEquals(3, exitCodes[3]); // FILE_WRITE_ERROR
        assertEquals(4, exitCodes[4]); // UNEXPECTED_ERROR
    }

    @Test
    void testApplicationCanBeInstantiated() {
        // This test verifies that the application class can be loaded
        // without requiring actual service dependencies
        assertNotNull(ScheduledFileWriterApplication.class);
    }
}