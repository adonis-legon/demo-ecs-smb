package com.example.scheduledfilewriter.model;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Objects;

/**
 * Model class representing file data with metadata.
 * Used to encapsulate file information including content, size, and creation
 * timestamp.
 */
public class FileData {

    private String filename;
    private byte[] content;
    private long size;
    private LocalDateTime createdAt;

    /**
     * Default constructor
     */
    public FileData() {
        this.createdAt = LocalDateTime.now();
    }

    /**
     * Constructor with filename and content
     * 
     * @param filename the name of the file
     * @param content  the file content as byte array
     */
    public FileData(String filename, byte[] content) {
        this.filename = filename;
        this.content = content != null ? content.clone() : null;
        this.size = content != null ? content.length : 0;
        this.createdAt = LocalDateTime.now();
    }

    /**
     * Full constructor
     * 
     * @param filename  the name of the file
     * @param content   the file content as byte array
     * @param size      the size of the file in bytes
     * @param createdAt the timestamp when the file was created
     */
    public FileData(String filename, byte[] content, long size, LocalDateTime createdAt) {
        this.filename = filename;
        this.content = content != null ? content.clone() : null;
        this.size = size;
        this.createdAt = createdAt;
    }

    // Getters and Setters

    public String getFilename() {
        return filename;
    }

    public void setFilename(String filename) {
        this.filename = filename;
    }

    public byte[] getContent() {
        return content != null ? content.clone() : null;
    }

    public void setContent(byte[] content) {
        this.content = content != null ? content.clone() : null;
        this.size = content != null ? content.length : 0;
    }

    public long getSize() {
        return size;
    }

    public void setSize(long size) {
        this.size = size;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o)
            return true;
        if (o == null || getClass() != o.getClass())
            return false;
        FileData fileData = (FileData) o;
        return size == fileData.size &&
                Objects.equals(filename, fileData.filename) &&
                Arrays.equals(content, fileData.content) &&
                Objects.equals(createdAt, fileData.createdAt);
    }

    @Override
    public int hashCode() {
        int result = Objects.hash(filename, size, createdAt);
        result = 31 * result + Arrays.hashCode(content);
        return result;
    }

    @Override
    public String toString() {
        return "FileData{" +
                "filename='" + filename + '\'' +
                ", size=" + size +
                ", createdAt=" + createdAt +
                ", contentLength=" + (content != null ? content.length : 0) +
                '}';
    }
}