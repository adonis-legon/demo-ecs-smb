package com.example.scheduledfilewriter.service;

import com.example.scheduledfilewriter.exception.SMBConnectionException;
import com.example.scheduledfilewriter.exception.SMBFileWriteException;
import com.example.scheduledfilewriter.model.ExecutionResult;
import com.example.scheduledfilewriter.model.SMBConnectionConfig;
import com.example.scheduledfilewriter.util.LoggingContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.integration.smb.session.SmbSession;
import org.springframework.integration.smb.session.SmbSessionFactory;
import org.springframework.integration.smb.outbound.SmbMessageHandler;
import org.springframework.integration.file.FileHeaders;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.expression.common.LiteralExpression;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.UUID;

/**
 * Service for writing files to SMB shares using Spring Integration SMB.
 * This service replaces the old JCIFS-based implementation with a more modern
 * Spring Integration approach that provides better compatibility and
 * reliability.
 */
@Service
public class FileWriterService {

    private static final Logger logger = LoggerFactory.getLogger(FileWriterService.class);
    private static final Random random = new Random();
    private static final DateTimeFormatter TIMESTAMP_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss");

    @Autowired
    private SmbSessionFactory smbSessionFactory;

    private SmbMessageHandler smbMessageHandler;

    @Value("${file.generation.count:5}")
    private int targetFileCount;

    @Value("${file.generation.size.min:1024}")
    private int minFileSize;

    @Value("${file.generation.size.max:10240}")
    private int maxFileSize;

    /**
     * Generates random files and writes them to the SMB share.
     *
     * @param config the SMB connection configuration
     * @return execution result with details of the operation
     */
    public ExecutionResult generateAndWriteFiles(SMBConnectionConfig config) {
        String correlationId = LoggingContext.generateCorrelationId();
        LoggingContext.setupExecutionContext("spring-integration-" + correlationId);
        LoggingContext.setOperation("FILE_GENERATION");

        logger.info("Starting file generation and write operation for {} files to host: {}",
                targetFileCount, config.getServerAddress());

        List<String> successfulFiles = new ArrayList<>();
        List<String> failedFiles = new ArrayList<>();

        try {
            // Test connection first
            testConnection();

            // Generate and write files
            for (int i = 1; i <= targetFileCount; i++) {
                try {
                    String filename = generateFilename(i);
                    byte[] content = generateRandomContent();

                    writeFileToSmb(filename, content);
                    successfulFiles.add(filename);

                    logger.info("File write loop: Successfully wrote file: {}", filename);

                } catch (Exception e) {
                    String filename = generateFilename(i);
                    failedFiles.add(filename);
                    logger.error("Failed to write file: {}", filename, e);
                }
            }

            // Determine result status
            String status = determineStatus(successfulFiles.size(), failedFiles.size());

            logger.info("File generation completed. Status: {}, Successful: {}, Failed: {}",
                    status, successfulFiles.size(), failedFiles.size());

            return new ExecutionResult(successfulFiles, status);

        } catch (Exception e) {
            logger.error("File generation operation failed", e);
            throw new SMBConnectionException("Failed to complete file generation operation", e);
        } finally {
            LoggingContext.clearAll();
        }
    }

    /**
     * Tests the SMB connection to ensure it's working.
     */
    private void testConnection() {
        try {
            logger.info("Testing SMB connection");

            // Test connection by getting a session directly
            try (SmbSession session = smbSessionFactory.getSession()) {
                logger.info("SMB connection test successful - session established");
                logger.info("Session details - Connected: {}", session != null);
            }

            logger.info("SMB connection test completed successfully");

        } catch (Exception e) {
            logger.error("SMB connection test failed - Error type: {} - Error message: {}",
                    e.getClass().getSimpleName(), e.getMessage());
            logger.error("Full stack trace for connection test failure:", e);

            if (e.getCause() != null) {
                logger.error("Root cause: {} - {}", e.getCause().getClass().getSimpleName(), e.getCause().getMessage());
            }

            throw new SMBConnectionException("Failed to establish SMB connection", e);
        }
    }

    /**
     * Writes a file to the SMB share using Spring Integration SMB.
     *
     * @param filename the name of the file to write
     * @param content  the file content as byte array
     */
    private void writeFileToSmb(String filename, byte[] content) {
        try {
            logger.info("Attempting to write file {} ({} bytes)", filename, content.length);

            // Initialize the message handler if not already done
            if (smbMessageHandler == null) {
                logger.info("Initializing SMB message handler");
                smbMessageHandler = new SmbMessageHandler(smbSessionFactory);
                // Use empty string to write to the share root directory
                // The SMB session factory is already configured with the share path
                smbMessageHandler.setRemoteDirectoryExpression(new LiteralExpression(""));
                smbMessageHandler.setAutoCreateDirectory(true);
                logger.info("SMB message handler initialized successfully");
            }

            // Create a message with the file content and filename
            logger.info("Creating message for file {} to SMB share", filename);
            var message = MessageBuilder.withPayload(content)
                    .setHeader(FileHeaders.FILENAME, filename)
                    .build();

            // Send the message using the handler
            logger.info("Sending file {} to SMB share", filename);
            smbMessageHandler.handleMessage(message);
            logger.info("File {} sent successfully to SMB share", filename);

            logger.info("Successfully wrote file: {}", filename);

        } catch (Exception e) {
            logger.error("Failed to write file: {} - Error type: {} - Error message: {}",
                    filename, e.getClass().getSimpleName(), e.getMessage());
            logger.error("Full stack trace for file write failure:", e);

            // Log additional details about the exception
            if (e.getCause() != null) {
                logger.error("Root cause: {} - {}", e.getCause().getClass().getSimpleName(), e.getCause().getMessage());
            }

            throw new SMBFileWriteException("Failed to write file: " + filename, e);
        }
    }

    /**
     * Generates a unique filename with timestamp.
     *
     * @param index the file index
     * @return generated filename
     */
    private String generateFilename(int index) {
        String timestamp = LocalDateTime.now().format(TIMESTAMP_FORMAT);
        String randomId = UUID.randomUUID().toString().substring(0, 8);
        return String.format("file_%s_%03d_%s.txt", timestamp, index, randomId);
    }

    /**
     * Generates random content for the file.
     *
     * @return random content as byte array
     */
    private byte[] generateRandomContent() {
        int size = minFileSize + random.nextInt(maxFileSize - minFileSize + 1);
        StringBuilder content = new StringBuilder();

        // Add header
        content.append("Generated file content\n");
        content.append("Timestamp: ").append(LocalDateTime.now()).append("\n");
        content.append("Size: ").append(size).append(" bytes\n");
        content.append("---\n");

        // Fill with random content
        String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 \n";
        while (content.length() < size) {
            content.append(chars.charAt(random.nextInt(chars.length())));
        }

        return content.toString().getBytes();
    }

    /**
     * Determines the execution status based on success/failure counts.
     *
     * @param successCount number of successful operations
     * @param failureCount number of failed operations
     * @return status string
     */
    private String determineStatus(int successCount, int failureCount) {
        if (failureCount == 0) {
            return "SUCCESS";
        } else if (successCount > 0) {
            return "PARTIAL_SUCCESS";
        } else {
            return "FAILURE";
        }
    }

    /**
     * Gets the target file count for this service.
     *
     * @return target file count
     */
    public int getTargetFileCount() {
        return targetFileCount;
    }
}