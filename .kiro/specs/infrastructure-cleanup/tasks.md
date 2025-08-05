# Implementation Plan

- [x] 1. Update compute stack template with embedded SMB setup

  - Replace the existing compute-stack.yaml with embedded SMB setup approach
  - Remove S3BucketName parameter and S3 access policies
  - Embed the complete SMB PowerShell script in UserData
  - Maintain all existing outputs and functionality
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 2. Update main template to use consolidated compute stack

  - Modify main-template.yaml to reference standard compute-stack.yaml
  - Remove S3BucketName parameter passing to compute stack
  - Keep S3 bucket parameter for networking and application stacks
  - Ensure backward compatibility with existing stacks
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 5.1, 5.2, 5.3, 5.4_

- [x] 3. Update deployment script with embedded SMB support

  - Modify deploy-stack.sh to work with updated templates
  - Remove S3 dependency validation for compute stack
  - Add validation for embedded SMB setup completion
  - Maintain same command-line interface and outputs
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 5.1, 5.2, 5.3, 5.4_

- [x] 4. Remove duplicate and temporary files

  - Delete compute-stack-no-s3.yaml file
  - Delete main-template-no-s3.yaml file
  - Delete deploy-no-s3.sh script
  - Delete deploy-no-s3.ps1 script
  - Delete diagnose-s3-issue.ps1 script
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 5. Validate consolidated infrastructure templates

  - Run CloudFormation template validation on updated compute-stack.yaml
  - Run CloudFormation template validation on updated main-template.yaml
  - Verify template size is within CloudFormation limits
  - Test nested stack references are correct
  - _Requirements: 1.1, 2.1, 5.1, 5.2, 5.3, 5.4_

- [x] 6. Test deployment with consolidated scripts
  - Deploy infrastructure using updated deploy-stack.sh
  - Verify Windows EC2 instance is created successfully
  - Confirm embedded SMB setup completes without errors
  - Validate SMB share is accessible with correct credentials
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 6.1, 6.2, 6.3, 6.4, 6.5_
