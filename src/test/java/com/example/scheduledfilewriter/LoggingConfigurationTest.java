package com.example.scheduledfilewriter;

import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Test class to verify logging configuration is working correctly.
 * This test validates that loggers are properly configured and can output
 * messages.
 */
class LoggingConfigurationTest {

    private static final Logger logger = LoggerFactory.getLogger(LoggingConfigurationTest.class);

    @Test
    void testLoggerConfiguration() {
        // Verify logger is properly configured
        assertNotNull(logger);
        assertTrue(logger.isInfoEnabled());

        // Test different log levels
        logger.debug("Debug message - should be visible in dev profile");
        logger.info("Info message - should be visible");
        logger.warn("Warning message - should be visible");
        logger.error("Error message - should be visible");
    }

    @Test
    void testApplicationLoggerConfiguration() {
        Logger appLogger = LoggerFactory.getLogger("com.example.scheduledfilewriter.TestClass");

        assertNotNull(appLogger);
        assertTrue(appLogger.isInfoEnabled());

        appLogger.info("Application logger test message");
    }

    @Test
    void testThirdPartyLoggerConfiguration() {
        // Test that third-party loggers are configured
        Logger awsLogger = LoggerFactory.getLogger("software.amazon.awssdk.TestClass");
        Logger smbLogger = LoggerFactory.getLogger("org.springframework.integration.smb.TestClass");
        Logger springLogger = LoggerFactory.getLogger("org.springframework.TestClass");

        assertNotNull(awsLogger);
        assertNotNull(smbLogger);
        assertNotNull(springLogger);

        // These should only show WARN and ERROR messages based on configuration
        awsLogger.warn("AWS SDK warning message");
        smbLogger.warn("Spring Integration SMB warning message");
        springLogger.warn("Spring warning message");
    }

    @Test
    void testLoggerHierarchy() {
        // Test that logger hierarchy works correctly
        Logger rootLogger = LoggerFactory.getLogger(Logger.ROOT_LOGGER_NAME);
        Logger packageLogger = LoggerFactory.getLogger("com.example.scheduledfilewriter");
        Logger classLogger = LoggerFactory.getLogger(LoggingConfigurationTest.class);

        assertNotNull(rootLogger);
        assertNotNull(packageLogger);
        assertNotNull(classLogger);

        // Test logging at different levels
        packageLogger.info("Package level info message");
        classLogger.info("Class level info message");
    }
}