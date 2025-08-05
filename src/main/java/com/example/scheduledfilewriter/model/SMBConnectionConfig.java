package com.example.scheduledfilewriter.model;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.Objects;

/**
 * Configuration class for SMB connection parameters.
 * Contains all necessary information to establish an SMB/CIFS connection.
 */
public class SMBConnectionConfig {

    @NotBlank(message = "Server address is required")
    private String serverAddress;

    @NotBlank(message = "Share name is required")
    private String shareName;

    @NotBlank(message = "Username is required")
    private String username;

    @NotBlank(message = "Password is required")
    private String password;

    @NotBlank(message = "Domain is required")
    private String domain;

    @NotNull(message = "Timeout is required")
    @Min(value = 1, message = "Timeout must be at least 1 second")
    private Integer timeout;

    /**
     * Default constructor
     */
    public SMBConnectionConfig() {
        this.timeout = 30; // Default timeout of 30 seconds
    }

    /**
     * Constructor with basic parameters
     * 
     * @param serverAddress the SMB server address
     * @param shareName     the name of the SMB share
     * @param username      the username for authentication
     * @param password      the password for authentication
     */
    public SMBConnectionConfig(String serverAddress, String shareName, String username, String password) {
        this.serverAddress = serverAddress;
        this.shareName = shareName;
        this.username = username;
        this.password = password;
        this.domain = "WORKGROUP"; // Default domain
        this.timeout = 30; // Default timeout
    }

    /**
     * Full constructor
     * 
     * @param serverAddress the SMB server address
     * @param shareName     the name of the SMB share
     * @param username      the username for authentication
     * @param password      the password for authentication
     * @param domain        the domain for authentication
     * @param timeout       the connection timeout in seconds
     */
    public SMBConnectionConfig(String serverAddress, String shareName, String username,
            String password, String domain, Integer timeout) {
        this.serverAddress = serverAddress;
        this.shareName = shareName;
        this.username = username;
        this.password = password;
        this.domain = domain;
        this.timeout = timeout;
    }

    // Getters and Setters

    public String getServerAddress() {
        return serverAddress;
    }

    public void setServerAddress(String serverAddress) {
        this.serverAddress = serverAddress;
    }

    public String getShareName() {
        return shareName;
    }

    public void setShareName(String shareName) {
        this.shareName = shareName;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getDomain() {
        return domain;
    }

    public void setDomain(String domain) {
        this.domain = domain;
    }

    public Integer getTimeout() {
        return timeout;
    }

    public void setTimeout(Integer timeout) {
        this.timeout = timeout;
    }

    // Utility methods

    /**
     * Get the full SMB URL for connection
     * 
     * @return the complete SMB URL
     */
    public String getSmbUrl() {
        return String.format("smb://%s/%s/", serverAddress, shareName);
    }

    /**
     * Get the domain-qualified username
     * 
     * @return username in domain\\username format
     */
    public String getDomainQualifiedUsername() {
        if (domain != null && !domain.trim().isEmpty()) {
            return domain + "\\" + username;
        }
        return username;
    }

    /**
     * Check if the configuration is valid for connection
     * 
     * @return true if all required fields are present
     */
    public boolean isValid() {
        return serverAddress != null && !serverAddress.trim().isEmpty() &&
                shareName != null && !shareName.trim().isEmpty() &&
                username != null && !username.trim().isEmpty() &&
                password != null && !password.trim().isEmpty() &&
                domain != null && !domain.trim().isEmpty() &&
                timeout != null && timeout > 0;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o)
            return true;
        if (o == null || getClass() != o.getClass())
            return false;
        SMBConnectionConfig that = (SMBConnectionConfig) o;
        return Objects.equals(serverAddress, that.serverAddress) &&
                Objects.equals(shareName, that.shareName) &&
                Objects.equals(username, that.username) &&
                Objects.equals(password, that.password) &&
                Objects.equals(domain, that.domain) &&
                Objects.equals(timeout, that.timeout);
    }

    @Override
    public int hashCode() {
        return Objects.hash(serverAddress, shareName, username, password, domain, timeout);
    }

    @Override
    public String toString() {
        return "SMBConnectionConfig{" +
                "serverAddress='" + serverAddress + '\'' +
                ", shareName='" + shareName + '\'' +
                ", username='" + username + '\'' +
                ", password='[PROTECTED]'" +
                ", domain='" + domain + '\'' +
                ", timeout=" + timeout +
                '}';
    }
}