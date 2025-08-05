package com.example.scheduledfilewriter.model;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import static org.junit.jupiter.api.Assertions.*;

import java.time.LocalDateTime;

class FileDataTest {

    private FileData fileData;
    private byte[] testContent;
    private String testFilename;
    private LocalDateTime testTimestamp;

    @BeforeEach
    void setUp() {
        testContent = "Test file content".getBytes();
        testFilename = "test-file.txt";
        testTimestamp = LocalDateTime.now();
    }

    @Test
    void testDefaultConstructor() {
        fileData = new FileData();

        assertNull(fileData.getFilename());
        assertNull(fileData.getContent());
        assertEquals(0, fileData.getSize());
        assertNotNull(fileData.getCreatedAt());
    }

    @Test
    void testConstructorWithFilenameAndContent() {
        fileData = new FileData(testFilename, testContent);

        assertEquals(testFilename, fileData.getFilename());
        assertArrayEquals(testContent, fileData.getContent());
        assertEquals(testContent.length, fileData.getSize());
        assertNotNull(fileData.getCreatedAt());
    }

    @Test
    void testConstructorWithNullContent() {
        fileData = new FileData(testFilename, null);

        assertEquals(testFilename, fileData.getFilename());
        assertNull(fileData.getContent());
        assertEquals(0, fileData.getSize());
        assertNotNull(fileData.getCreatedAt());
    }

    @Test
    void testFullConstructor() {
        fileData = new FileData(testFilename, testContent, testContent.length, testTimestamp);

        assertEquals(testFilename, fileData.getFilename());
        assertArrayEquals(testContent, fileData.getContent());
        assertEquals(testContent.length, fileData.getSize());
        assertEquals(testTimestamp, fileData.getCreatedAt());
    }

    @Test
    void testSetFilename() {
        fileData = new FileData();
        String newFilename = "new-file.txt";

        fileData.setFilename(newFilename);

        assertEquals(newFilename, fileData.getFilename());
    }

    @Test
    void testSetContent() {
        fileData = new FileData();
        byte[] newContent = "New content".getBytes();

        fileData.setContent(newContent);

        assertArrayEquals(newContent, fileData.getContent());
        assertEquals(newContent.length, fileData.getSize());
    }

    @Test
    void testSetContentWithNull() {
        fileData = new FileData(testFilename, testContent);

        fileData.setContent(null);

        assertNull(fileData.getContent());
        assertEquals(0, fileData.getSize());
    }

    @Test
    void testSetSize() {
        fileData = new FileData();
        long newSize = 1024L;

        fileData.setSize(newSize);

        assertEquals(newSize, fileData.getSize());
    }

    @Test
    void testSetCreatedAt() {
        fileData = new FileData();
        LocalDateTime newTimestamp = LocalDateTime.of(2024, 1, 1, 12, 0);

        fileData.setCreatedAt(newTimestamp);

        assertEquals(newTimestamp, fileData.getCreatedAt());
    }

    @Test
    void testContentImmutability() {
        byte[] originalContent = "Original content".getBytes();
        fileData = new FileData(testFilename, originalContent);

        // Modify the original array
        originalContent[0] = 'X';

        // FileData content should not be affected
        assertNotEquals('X', fileData.getContent()[0]);
        assertEquals('O', fileData.getContent()[0]);
    }

    @Test
    void testGetContentImmutability() {
        fileData = new FileData(testFilename, testContent);

        byte[] retrievedContent = fileData.getContent();
        retrievedContent[0] = 'X';

        // Original content in FileData should not be affected
        assertNotEquals('X', fileData.getContent()[0]);
        assertEquals('T', fileData.getContent()[0]);
    }

    @Test
    void testEquals() {
        FileData fileData1 = new FileData(testFilename, testContent, testContent.length, testTimestamp);
        FileData fileData2 = new FileData(testFilename, testContent, testContent.length, testTimestamp);

        assertEquals(fileData1, fileData2);
    }

    @Test
    void testNotEquals() {
        FileData fileData1 = new FileData(testFilename, testContent);
        FileData fileData2 = new FileData("different-file.txt", testContent);

        assertNotEquals(fileData1, fileData2);
    }

    @Test
    void testHashCode() {
        FileData fileData1 = new FileData(testFilename, testContent, testContent.length, testTimestamp);
        FileData fileData2 = new FileData(testFilename, testContent, testContent.length, testTimestamp);

        assertEquals(fileData1.hashCode(), fileData2.hashCode());
    }

    @Test
    void testToString() {
        fileData = new FileData(testFilename, testContent);
        String result = fileData.toString();

        assertTrue(result.contains(testFilename));
        assertTrue(result.contains(String.valueOf(testContent.length)));
        assertTrue(result.contains("FileData{"));
    }

    @Test
    void testToStringWithNullContent() {
        fileData = new FileData(testFilename, null);
        String result = fileData.toString();

        assertTrue(result.contains(testFilename));
        assertTrue(result.contains("contentLength=0"));
        assertTrue(result.contains("FileData{"));
    }
}