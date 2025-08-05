package com.example.scheduledfilewriter.model;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/**
 * Model class representing the result of a file writing execution.
 * Used to track task execution outcomes including created files, counts,
 * timing, and status.
 */
public class ExecutionResult {

    private List<String> createdFiles;
    private int totalFilesCreated;
    private LocalDateTime executionTime;
    private String status;
    private String errorMessage;

    /**
     * Default constructor
     */
    public ExecutionResult() {
        this.createdFiles = new ArrayList<>();
        this.totalFilesCreated = 0;
        this.executionTime = LocalDateTime.now();
        this.status = "PENDING";
    }

    /**
     * Constructor with basic parameters
     * 
     * @param createdFiles list of created file names
     * @param status       execution status
     */
    public ExecutionResult(List<String> createdFiles, String status) {
        this.createdFiles = createdFiles != null ? new ArrayList<>(createdFiles) : new ArrayList<>();
        this.totalFilesCreated = this.createdFiles.size();
        this.executionTime = LocalDateTime.now();
        this.status = status;
    }

    /**
     * Full constructor
     * 
     * @param createdFiles      list of created file names
     * @param totalFilesCreated total count of files created
     * @param executionTime     timestamp of execution
     * @param status            execution status
     * @param errorMessage      error message if execution failed
     */
    public ExecutionResult(List<String> createdFiles, int totalFilesCreated,
            LocalDateTime executionTime, String status, String errorMessage) {
        this.createdFiles = createdFiles != null ? new ArrayList<>(createdFiles) : new ArrayList<>();
        this.totalFilesCreated = totalFilesCreated;
        this.executionTime = executionTime;
        this.status = status;
        this.errorMessage = errorMessage;
    }

    // Getters and Setters

    public List<String> getCreatedFiles() {
        return new ArrayList<>(createdFiles);
    }

    public void setCreatedFiles(List<String> createdFiles) {
        this.createdFiles = createdFiles != null ? new ArrayList<>(createdFiles) : new ArrayList<>();
        this.totalFilesCreated = this.createdFiles.size();
    }

    public int getTotalFilesCreated() {
        return totalFilesCreated;
    }

    public void setTotalFilesCreated(int totalFilesCreated) {
        this.totalFilesCreated = totalFilesCreated;
    }

    public LocalDateTime getExecutionTime() {
        return executionTime;
    }

    public void setExecutionTime(LocalDateTime executionTime) {
        this.executionTime = executionTime;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }

    // Utility methods

    /**
     * Add a created file to the list
     * 
     * @param filename the name of the created file
     */
    public void addCreatedFile(String filename) {
        if (filename != null && !filename.trim().isEmpty()) {
            this.createdFiles.add(filename);
            this.totalFilesCreated = this.createdFiles.size();
        }
    }

    /**
     * Check if the execution was successful
     * 
     * @return true if status indicates success
     */
    public boolean isSuccess() {
        return "SUCCESS".equalsIgnoreCase(status) || "COMPLETED".equalsIgnoreCase(status);
    }

    /**
     * Check if the execution failed
     * 
     * @return true if status indicates failure
     */
    public boolean isFailure() {
        return "FAILURE".equalsIgnoreCase(status) || "ERROR".equalsIgnoreCase(status)
                || "FAILED".equalsIgnoreCase(status);
    }

    /**
     * Check if there were partial failures (some files created, some failed)
     * 
     * @return true if there were partial failures
     */
    public boolean hasPartialFailures() {
        return totalFilesCreated > 0 && (isFailure() || errorMessage != null);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o)
            return true;
        if (o == null || getClass() != o.getClass())
            return false;
        ExecutionResult that = (ExecutionResult) o;
        return totalFilesCreated == that.totalFilesCreated &&
                Objects.equals(createdFiles, that.createdFiles) &&
                Objects.equals(executionTime, that.executionTime) &&
                Objects.equals(status, that.status) &&
                Objects.equals(errorMessage, that.errorMessage);
    }

    @Override
    public int hashCode() {
        return Objects.hash(createdFiles, totalFilesCreated, executionTime, status, errorMessage);
    }

    @Override
    public String toString() {
        return "ExecutionResult{" +
                "createdFiles=" + createdFiles +
                ", totalFilesCreated=" + totalFilesCreated +
                ", executionTime=" + executionTime +
                ", status='" + status + '\'' +
                ", errorMessage='" + errorMessage + '\'' +
                '}';
    }
}