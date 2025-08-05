# Infrastructure Cleanup Requirements

## Introduction

This feature consolidates the infrastructure templates and deployment scripts to eliminate confusion from multiple file versions. The goal is to have a single, clean set of files that use the embedded SMB setup approach (no S3 dependency) while maintaining the original file naming structure.

## Requirements

### Requirement 1: Consolidate Compute Stack Templates

**User Story:** As a developer, I want a single compute-stack.yaml file that uses embedded SMB setup, so that I don't have to manage multiple versions of the same template.

#### Acceptance Criteria

1. WHEN I look in infrastructure/templates/ THEN I SHALL see only one compute-stack.yaml file
2. WHEN the compute stack is deployed THEN it SHALL use embedded SMB setup in UserData without requiring S3 script downloads
3. WHEN the compute stack is deployed THEN it SHALL NOT include S3 access policies or parameters for SMB setup
4. WHEN the embedded SMB setup runs THEN it SHALL create the SMB share with the same functionality as the original script

### Requirement 2: Consolidate Main Template

**User Story:** As a developer, I want a single main-template.yaml file that references the updated compute stack, so that I have a clean deployment structure.

#### Acceptance Criteria

1. WHEN I look in infrastructure/ THEN I SHALL see only one main-template.yaml file
2. WHEN the main template is used THEN it SHALL reference the updated compute-stack.yaml (not compute-stack-no-s3.yaml)
3. WHEN the main template is deployed THEN it SHALL work with the existing networking and application stacks
4. WHEN the main template is deployed THEN it SHALL NOT pass S3BucketName parameter to the compute stack

### Requirement 3: Consolidate Deployment Scripts

**User Story:** As a developer, I want to use the original deployment script names, so that I don't have to remember new script names or maintain multiple versions.

#### Acceptance Criteria

1. WHEN I look in scripts/ THEN I SHALL see the original deploy-stack.sh script updated with the new functionality
2. WHEN I run deploy-stack.sh THEN it SHALL deploy the infrastructure with embedded SMB setup
3. WHEN I run deploy-stack.sh THEN it SHALL NOT require separate _-no-s3._ scripts
4. WHEN deployment completes THEN it SHALL provide the same outputs as before (Windows IP, SMB share path, etc.)

### Requirement 4: Remove Duplicate Files

**User Story:** As a developer, I want duplicate and temporary files removed, so that the project structure is clean and maintainable.

#### Acceptance Criteria

1. WHEN cleanup is complete THEN compute-stack-no-s3.yaml SHALL be removed
2. WHEN cleanup is complete THEN main-template-no-s3.yaml SHALL be removed
3. WHEN cleanup is complete THEN deploy-no-s3.sh SHALL be removed
4. WHEN cleanup is complete THEN deploy-no-s3.ps1 SHALL be removed
5. WHEN cleanup is complete THEN diagnose-s3-issue.ps1 SHALL be removed

### Requirement 5: Maintain Backward Compatibility

**User Story:** As a developer, I want the updated templates to work with existing infrastructure, so that I don't break current deployments.

#### Acceptance Criteria

1. WHEN the updated templates are deployed THEN they SHALL work with existing networking-stack.yaml
2. WHEN the updated templates are deployed THEN they SHALL work with existing application-stack.yaml
3. WHEN the updated templates are deployed THEN they SHALL produce the same stack outputs as before
4. WHEN the updated templates are deployed THEN they SHALL use the same parameter names and types as before (except removing S3-related ones)

### Requirement 6: Preserve SMB Functionality

**User Story:** As a developer, I want the embedded SMB setup to have the same functionality as the original script, so that the ECS application can connect to the SMB share without issues.

#### Acceptance Criteria

1. WHEN the embedded SMB setup runs THEN it SHALL create the same SMB user and share as the original script
2. WHEN the embedded SMB setup runs THEN it SHALL configure the same firewall rules as the original script
3. WHEN the embedded SMB setup runs THEN it SHALL create the same test files as the original script
4. WHEN the embedded SMB setup completes THEN it SHALL log the same success/failure information as the original script
5. WHEN the ECS application connects THEN it SHALL be able to access the SMB share with the same credentials and path as before
