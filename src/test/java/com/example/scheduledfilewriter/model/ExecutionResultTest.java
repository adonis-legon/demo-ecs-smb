package com.example.scheduledfilewriter.model;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.ArrayList;

class ExecutionResultTest {

    private ExecutionResult executionResult;
    private List<String> testFiles;
    private LocalDateTime testTimestamp;

    @BeforeEach
    void setUp() {
        testFiles = Arrays.asList("file1.txt", "file2.txt", "file3.txt");
        testTimestamp = LocalDateTime.now();
    }

    @Test
    void testDefaultConstructor() {
        executionResult = new ExecutionResult();

        assertNotNull(executionResult.getCreatedFiles());
        assertTrue(executionResult.getCreatedFiles().isEmpty());
        assertEquals(0, executionResult.getTotalFilesCreated());
        assertNotNull(executionResult.getExecutionTime());
        assertEquals("PENDING", executionResult.getStatus());
        assertNull(executionResult.getErrorMessage());
    }

    @Test
    void testConstructorWithFilesAndStatus() {
        executionResult = new ExecutionResult(testFiles, "SUCCESS");

        assertEquals(testFiles, executionResult.getCreatedFiles());
        assertEquals(testFiles.size(), executionResult.getTotalFilesCreated());
        assertNotNull(executionResult.getExecutionTime());
        assertEquals("SUCCESS", executionResult.getStatus());
        assertNull(executionResult.getErrorMessage());
    }

    @Test
    void testConstructorWithNullFiles() {
        executionResult = new ExecutionResult(null, "SUCCESS");

        assertNotNull(executionResult.getCreatedFiles());
        assertTrue(executionResult.getCreatedFiles().isEmpty());
        assertEquals(0, executionResult.getTotalFilesCreated());
        assertEquals("SUCCESS", executionResult.getStatus());
    }

    @Test
    void testFullConstructor() {
        String errorMessage = "Connection failed";
        executionResult = new ExecutionResult(testFiles, testFiles.size(), testTimestamp, "FAILURE", errorMessage);

        assertEquals(testFiles, executionResult.getCreatedFiles());
        assertEquals(testFiles.size(), executionResult.getTotalFilesCreated());
        assertEquals(testTimestamp, executionResult.getExecutionTime());
        assertEquals("FAILURE", executionResult.getStatus());
        assertEquals(errorMessage, executionResult.getErrorMessage());
    }

    @Test
    void testSetCreatedFiles() {
        executionResult = new ExecutionResult();
        List<String> newFiles = Arrays.asList("new1.txt", "new2.txt");

        executionResult.setCreatedFiles(newFiles);

        assertEquals(newFiles, executionResult.getCreatedFiles());
        assertEquals(newFiles.size(), executionResult.getTotalFilesCreated());
    }

    @Test
    void testSetCreatedFilesWithNull() {
        executionResult = new ExecutionResult(testFiles, "SUCCESS");

        executionResult.setCreatedFiles(null);

        assertNotNull(executionResult.getCreatedFiles());
        assertTrue(executionResult.getCreatedFiles().isEmpty());
        assertEquals(0, executionResult.getTotalFilesCreated());
    }

    @Test
    void testSetTotalFilesCreated() {
        executionResult = new ExecutionResult();
        int newCount = 5;

        executionResult.setTotalFilesCreated(newCount);

        assertEquals(newCount, executionResult.getTotalFilesCreated());
    }

    @Test
    void testSetExecutionTime() {
        executionResult = new ExecutionResult();
        LocalDateTime newTime = LocalDateTime.of(2024, 1, 1, 12, 0);

        executionResult.setExecutionTime(newTime);

        assertEquals(newTime, executionResult.getExecutionTime());
    }

    @Test
    void testSetStatus() {
        executionResult = new ExecutionResult();
        String newStatus = "COMPLETED";

        executionResult.setStatus(newStatus);

        assertEquals(newStatus, executionResult.getStatus());
    }

    @Test
    void testSetErrorMessage() {
        executionResult = new ExecutionResult();
        String errorMessage = "Test error";

        executionResult.setErrorMessage(errorMessage);

        assertEquals(errorMessage, executionResult.getErrorMessage());
    }

    @Test
    void testAddCreatedFile() {
        executionResult = new ExecutionResult();
        String filename = "test.txt";

        executionResult.addCreatedFile(filename);

        assertTrue(executionResult.getCreatedFiles().contains(filename));
        assertEquals(1, executionResult.getTotalFilesCreated());
    }

    @Test
    void testAddCreatedFileWithNull() {
        executionResult = new ExecutionResult();

        executionResult.addCreatedFile(null);

        assertTrue(executionResult.getCreatedFiles().isEmpty());
        assertEquals(0, executionResult.getTotalFilesCreated());
    }

    @Test
    void testAddCreatedFileWithEmptyString() {
        executionResult = new ExecutionResult();

        executionResult.addCreatedFile("");
        executionResult.addCreatedFile("   ");

        assertTrue(executionResult.getCreatedFiles().isEmpty());
        assertEquals(0, executionResult.getTotalFilesCreated());
    }

    @Test
    void testAddMultipleCreatedFiles() {
        executionResult = new ExecutionResult();

        executionResult.addCreatedFile("file1.txt");
        executionResult.addCreatedFile("file2.txt");
        executionResult.addCreatedFile("file3.txt");

        assertEquals(3, executionResult.getTotalFilesCreated());
        assertTrue(executionResult.getCreatedFiles().contains("file1.txt"));
        assertTrue(executionResult.getCreatedFiles().contains("file2.txt"));
        assertTrue(executionResult.getCreatedFiles().contains("file3.txt"));
    }

    @Test
    void testIsSuccessWithSuccessStatus() {
        executionResult = new ExecutionResult(testFiles, "SUCCESS");
        assertTrue(executionResult.isSuccess());

        executionResult.setStatus("success");
        assertTrue(executionResult.isSuccess());

        executionResult.setStatus("COMPLETED");
        assertTrue(executionResult.isSuccess());

        executionResult.setStatus("completed");
        assertTrue(executionResult.isSuccess());
    }

    @Test
    void testIsSuccessWithFailureStatus() {
        executionResult = new ExecutionResult(testFiles, "FAILURE");
        assertFalse(executionResult.isSuccess());

        executionResult.setStatus("PENDING");
        assertFalse(executionResult.isSuccess());
    }

    @Test
    void testIsFailureWithFailureStatus() {
        executionResult = new ExecutionResult(testFiles, "FAILURE");
        assertTrue(executionResult.isFailure());

        executionResult.setStatus("failure");
        assertTrue(executionResult.isFailure());

        executionResult.setStatus("ERROR");
        assertTrue(executionResult.isFailure());

        executionResult.setStatus("error");
        assertTrue(executionResult.isFailure());

        executionResult.setStatus("FAILED");
        assertTrue(executionResult.isFailure());

        executionResult.setStatus("failed");
        assertTrue(executionResult.isFailure());
    }

    @Test
    void testIsFailureWithSuccessStatus() {
        executionResult = new ExecutionResult(testFiles, "SUCCESS");
        assertFalse(executionResult.isFailure());

        executionResult.setStatus("PENDING");
        assertFalse(executionResult.isFailure());
    }

    @Test
    void testHasPartialFailures() {
        // Test with files created but failure status
        executionResult = new ExecutionResult(testFiles, "FAILURE");
        assertTrue(executionResult.hasPartialFailures());

        // Test with files created but error message
        executionResult = new ExecutionResult(testFiles, "SUCCESS");
        executionResult.setErrorMessage("Some files failed");
        assertTrue(executionResult.hasPartialFailures());

        // Test with no files created
        executionResult = new ExecutionResult(new ArrayList<>(), "FAILURE");
        assertFalse(executionResult.hasPartialFailures());

        // Test with success and no error message
        executionResult = new ExecutionResult(testFiles, "SUCCESS");
        assertFalse(executionResult.hasPartialFailures());
    }

    @Test
    void testCreatedFilesImmutability() {
        List<String> originalFiles = new ArrayList<>(testFiles);
        executionResult = new ExecutionResult(originalFiles, "SUCCESS");

        // Modify the original list
        originalFiles.add("new-file.txt");

        // ExecutionResult should not be affected
        assertEquals(testFiles.size(), executionResult.getCreatedFiles().size());
        assertFalse(executionResult.getCreatedFiles().contains("new-file.txt"));
    }

    @Test
    void testGetCreatedFilesImmutability() {
        executionResult = new ExecutionResult(testFiles, "SUCCESS");

        List<String> retrievedFiles = executionResult.getCreatedFiles();
        retrievedFiles.add("new-file.txt");

        // Original list in ExecutionResult should not be affected
        assertEquals(testFiles.size(), executionResult.getCreatedFiles().size());
        assertFalse(executionResult.getCreatedFiles().contains("new-file.txt"));
    }

    @Test
    void testEquals() {
        ExecutionResult result1 = new ExecutionResult(testFiles, testFiles.size(), testTimestamp, "SUCCESS", null);
        ExecutionResult result2 = new ExecutionResult(testFiles, testFiles.size(), testTimestamp, "SUCCESS", null);

        assertEquals(result1, result2);
    }

    @Test
    void testNotEquals() {
        ExecutionResult result1 = new ExecutionResult(testFiles, "SUCCESS");
        ExecutionResult result2 = new ExecutionResult(testFiles, "FAILURE");

        assertNotEquals(result1, result2);
    }

    @Test
    void testHashCode() {
        ExecutionResult result1 = new ExecutionResult(testFiles, testFiles.size(), testTimestamp, "SUCCESS", null);
        ExecutionResult result2 = new ExecutionResult(testFiles, testFiles.size(), testTimestamp, "SUCCESS", null);

        assertEquals(result1.hashCode(), result2.hashCode());
    }

    @Test
    void testToString() {
        executionResult = new ExecutionResult(testFiles, "SUCCESS");
        String result = executionResult.toString();

        assertTrue(result.contains("ExecutionResult{"));
        assertTrue(result.contains("SUCCESS"));
        assertTrue(result.contains(String.valueOf(testFiles.size())));
    }

    @Test
    void testToStringWithErrorMessage() {
        String errorMessage = "Test error";
        executionResult = new ExecutionResult(testFiles, testFiles.size(), testTimestamp, "FAILURE", errorMessage);
        String result = executionResult.toString();

        assertTrue(result.contains("ExecutionResult{"));
        assertTrue(result.contains("FAILURE"));
        assertTrue(result.contains(errorMessage));
    }
}