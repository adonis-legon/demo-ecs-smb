package com.example.scheduledfilewriter;

import com.example.scheduledfilewriter.exception.ConfigurationException;
import com.example.scheduledfilewriter.exception.SMBConnectionException;
import com.example.scheduledfilewriter.exception.SMBFileWriteException;
import com.example.scheduledfilewriter.model.ExecutionResult;
import com.example.scheduledfilewriter.model.SMBConnectionConfig;
import com.example.scheduledfilewriter.service.ConfigurationService;
import com.example.scheduledfilewriter.service.FileWriterService;

import com.example.scheduledfilewriter.util.LoggingContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Main Spring Boot application class for the Scheduled File Writer.
 * This console application connects to an SMB/CIFS file share to generate and
 * write random files on a scheduled basis. It uses Spring Integration SMB
 * for reliable and modern SMB connectivity, integrating ConfigurationService
 * and FileWriterService to perform the complete file writing operation.
 */
@SpringBootApplication
public class ScheduledFileWriterApplication implements CommandLineRunner {

    private static final Logger logger = LoggerFactory.getLogger(ScheduledFileWriterApplication.class);

    // Exit codes for different scenarios
    private static final int EXIT_SUCCESS = 0;
    private static final int EXIT_CONFIGURATION_ERROR = 1;
    private static final int EXIT_CONNECTION_ERROR = 2;
    private static final int EXIT_FILE_WRITE_ERROR = 3;
    private static final int EXIT_UNEXPECTED_ERROR = 4;

    private final ConfigurationService configurationService;
    private final FileWriterService fileWriterService;

    @Value("${spring.profiles.active:}")
    private String activeProfiles;

    public ScheduledFileWriterApplication(ConfigurationService configurationService,
            FileWriterService fileWriterService) {
        this.configurationService = configurationService;
        this.fileWriterService = fileWriterService;
    }

    public static void main(String[] args) {
        logger.info("Starting Scheduled File Writer Application...");

        // Configure Spring Boot to exit after CommandLineRunner completes
        System.setProperty("spring.main.web-application-type", "none");

        // Add shutdown hook for graceful cleanup
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            logger.info("Shutdown hook triggered - performing graceful cleanup...");
            LoggingContext.clearAll();
            logger.info("Application shutdown completed");
        }));

        try {
            SpringApplication app = new SpringApplication(ScheduledFileWriterApplication.class);
            app.setLogStartupInfo(false); // Reduce startup noise
            System.exit(SpringApplication.exit(app.run(args)));
        } catch (Exception e) {
            logger.error("Failed to start application", e);
            System.exit(EXIT_UNEXPECTED_ERROR);
        }
    }

    @Override
    public void run(String... args) throws Exception {
        // Skip execution during tests
        if (activeProfiles.contains("test") || System.getProperty("spring.profiles.active", "").contains("test")) {
            logger.info("Test profile detected - skipping CommandLineRunner execution");
            return;
        }

        String executionId = LoggingContext.generateExecutionId();
        String correlationId = LoggingContext.setupExecutionContext(executionId);

        logger.info("Starting file writing execution with ID: {} and correlation ID: {}", executionId, correlationId);

        long startTime = System.currentTimeMillis();
        ExecutionResult result = null;
        int exitCode = EXIT_SUCCESS;

        try {
            // Step 1: Validate configuration
            LoggingContext.setOperation("configuration_validation");
            logger.info("Validating application configuration...");
            long configStartTime = System.currentTimeMillis();

            configurationService.validateConfiguration();

            long configDuration = System.currentTimeMillis() - configStartTime;
            LoggingContext.setDuration(configDuration);
            logger.info("Configuration validation completed successfully in {}ms", configDuration);
            LoggingContext.clearOperationContext();

            // Step 2: Get connection settings
            LoggingContext.setOperation("connection_settings_retrieval");
            logger.info("Retrieving SMB connection settings...");
            long settingsStartTime = System.currentTimeMillis();

            SMBConnectionConfig connectionConfig = configurationService.getConnectionSettings();

            long settingsDuration = System.currentTimeMillis() - settingsStartTime;
            LoggingContext.setDuration(settingsDuration);
            LoggingContext.setConnectionStatus("CONFIGURED");
            logger.info("Successfully retrieved connection settings for host: {} in {}ms",
                    connectionConfig.getServerAddress(), settingsDuration);
            LoggingContext.clearOperationContext();

            // Step 3: Execute file generation and writing
            LoggingContext.setOperation("file_generation_and_writing");
            logger.info("Starting file generation and writing process...");
            long fileOpStartTime = System.currentTimeMillis();

            // Use Spring Integration SMB service
            logger.info("Using Spring Integration SMB service");
            result = fileWriterService.generateAndWriteFiles(connectionConfig);

            long fileOpDuration = System.currentTimeMillis() - fileOpStartTime;
            LoggingContext.setDuration(fileOpDuration);
            LoggingContext.setFileCount(result != null ? result.getTotalFilesCreated() : 0);

            String performanceMetrics = LoggingContext.createPerformanceMetrics(
                    "file_generation_and_writing", fileOpStartTime,
                    result != null ? result.getTotalFilesCreated() : 0,
                    result != null && result.isSuccess());
            logger.info(performanceMetrics);
            LoggingContext.clearOperationContext();

            // Step 4: Process results and determine exit status
            exitCode = processExecutionResult(result, executionId);

        } catch (ConfigurationException e) {
            LoggingContext.setErrorType("CONFIGURATION_ERROR");
            logger.error("Configuration error in execution {}: {}", executionId, e.getMessage());
            exitCode = EXIT_CONFIGURATION_ERROR;

        } catch (SMBConnectionException e) {
            LoggingContext.setErrorType("SMB_CONNECTION_ERROR");
            LoggingContext.setConnectionStatus("FAILED");
            logger.error("SMB connection error in execution {}: {}", executionId, e.getMessage());
            exitCode = EXIT_CONNECTION_ERROR;

        } catch (SMBFileWriteException e) {
            LoggingContext.setErrorType("SMB_FILE_WRITE_ERROR");
            logger.error("File write error in execution {}: {}", executionId, e.getMessage());
            exitCode = EXIT_FILE_WRITE_ERROR;

        } catch (Exception e) {
            LoggingContext.setErrorType("UNEXPECTED_ERROR");
            logger.error("Unexpected error in execution {}: {}", executionId, e.getMessage(), e);
            exitCode = EXIT_UNEXPECTED_ERROR;

        } finally {
            // Step 5: Cleanup and final logging
            performCleanup(executionId, startTime, result, exitCode);
            LoggingContext.clearAll();
        }

        // Exit with appropriate code
        if (exitCode != EXIT_SUCCESS) {
            throw new RuntimeException("Application completed with exit code: " + exitCode);
        }
    }

    /**
     * Processes the execution result and determines the appropriate exit code.
     * 
     * @param result      the execution result from file writing operation
     * @param executionId the unique execution identifier
     * @return the appropriate exit code
     */
    private int processExecutionResult(ExecutionResult result, String executionId) {
        if (result == null) {
            logger.error("Execution {} returned null result", executionId);
            return EXIT_UNEXPECTED_ERROR;
        }

        logger.info("Execution {} completed with status: {}", executionId, result.getStatus());
        logger.info("Files created: {} out of {} target files",
                result.getTotalFilesCreated(), fileWriterService.getTargetFileCount());

        // Log created files
        if (!result.getCreatedFiles().isEmpty()) {
            logger.info("Successfully created files:");
            for (String filename : result.getCreatedFiles()) {
                logger.info("  - {}", filename);
            }
        }

        // Determine exit code based on result status
        switch (result.getStatus().toUpperCase()) {
            case "SUCCESS":
                logger.info("Execution {} completed successfully", executionId);
                return EXIT_SUCCESS;

            case "PARTIAL_SUCCESS":
                logger.warn("Execution {} completed with partial success: {}",
                        executionId, result.getErrorMessage());
                return EXIT_FILE_WRITE_ERROR;

            case "FAILURE":
                logger.error("Execution {} failed: {}", executionId, result.getErrorMessage());
                return EXIT_FILE_WRITE_ERROR;

            default:
                logger.error("Execution {} returned unknown status: {}", executionId, result.getStatus());
                return EXIT_UNEXPECTED_ERROR;
        }
    }

    /**
     * Performs comprehensive cleanup operations and final logging.
     * Includes graceful shutdown of SMB connections, resource cleanup,
     * and performance metrics logging.
     * 
     * @param executionId the unique execution identifier
     * @param startTime   the execution start time in milliseconds
     * @param result      the execution result (may be null)
     * @param exitCode    the final exit code
     */
    private void performCleanup(String executionId, long startTime, ExecutionResult result, int exitCode) {
        LoggingContext.setOperation("cleanup");
        long cleanupStartTime = System.currentTimeMillis();

        try {
            // Step 1: Graceful SMB connection shutdown
            logger.debug("Initiating graceful SMB connection shutdown...");
            // Spring Integration SMB handles connection cleanup automatically
            LoggingContext.setConnectionStatus("DISCONNECTED");
            logger.debug("SMB connections cleaned up automatically by Spring Integration");

            // Step 2: Clear any temporary resources
            logger.debug("Clearing temporary resources...");
            // Note: In this application, we don't have temporary files or other resources
            // but this is where they would be cleaned up

            // Step 3: Calculate and log performance metrics
            long executionTimeMs = System.currentTimeMillis() - startTime;
            long cleanupTimeMs = System.currentTimeMillis() - cleanupStartTime;

            LoggingContext.setDuration(executionTimeMs);
            LoggingContext.setFileCount(result != null ? result.getTotalFilesCreated() : 0);

            // Step 4: Generate comprehensive execution summary
            String performanceMetrics = LoggingContext.createPerformanceMetrics(
                    "complete_execution", startTime,
                    result != null ? result.getTotalFilesCreated() : 0,
                    exitCode == EXIT_SUCCESS);

            // Step 5: Final summary logging
            logger.info("Execution {} summary:", executionId);
            logger.info("  - Total execution time: {} ms", executionTimeMs);
            logger.info("  - Cleanup time: {} ms", cleanupTimeMs);
            logger.info("  - Exit code: {} ({})", exitCode, getExitCodeDescription(exitCode));
            logger.info("  - Files created: {}", result != null ? result.getTotalFilesCreated() : 0);
            logger.info("  - Final status: {}", result != null ? result.getStatus() : "UNKNOWN");
            logger.info("  - Performance: {}", performanceMetrics);

            if (result != null && result.getErrorMessage() != null) {
                logger.info("  - Error details: {}", result.getErrorMessage());
            }

            // Step 6: Log final completion status
            if (exitCode == EXIT_SUCCESS) {
                logger.info("Application completed successfully");
            } else {
                logger.error("Application completed with errors (exit code: {})", exitCode);
            }

        } catch (Exception e) {
            logger.warn("Error during cleanup operation: {}", e.getMessage(), e);
            // Don't throw exception during cleanup to avoid masking original error
        } finally {
            LoggingContext.clearOperationContext();
        }
    }

    /**
     * Gets a human-readable description for an exit code.
     * 
     * @param exitCode the exit code
     * @return a description of the exit code
     */
    private String getExitCodeDescription(int exitCode) {
        switch (exitCode) {
            case EXIT_SUCCESS:
                return "SUCCESS";
            case EXIT_CONFIGURATION_ERROR:
                return "CONFIGURATION_ERROR";
            case EXIT_CONNECTION_ERROR:
                return "CONNECTION_ERROR";
            case EXIT_FILE_WRITE_ERROR:
                return "FILE_WRITE_ERROR";
            case EXIT_UNEXPECTED_ERROR:
                return "UNEXPECTED_ERROR";
            default:
                return "UNKNOWN_ERROR";
        }
    }

    /**
     * Gets the exit code constants for testing purposes.
     * 
     * @return array of exit codes in order: SUCCESS, CONFIG_ERROR,
     *         CONNECTION_ERROR, FILE_WRITE_ERROR, UNEXPECTED_ERROR
     */
    public static int[] getExitCodes() {
        return new int[] { EXIT_SUCCESS, EXIT_CONFIGURATION_ERROR, EXIT_CONNECTION_ERROR,
                EXIT_FILE_WRITE_ERROR, EXIT_UNEXPECTED_ERROR };
    }
}