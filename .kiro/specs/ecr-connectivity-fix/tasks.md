# Implementation Plan

- [x] 1. Add S3 Gateway VPC Endpoint to CloudFormation template ✅ COMPLETED

  - ✅ Added S3 gateway VPC endpoint resource to enable ECR image layer downloads
  - ✅ Configured route table association for private subnet
  - ✅ Added comprehensive IAM policy document for S3 access including ECR starport bucket
  - ✅ Included conditional access for repository-tagged objects
  - _Requirements: 2.1, 2.2_

- [x] 2. Enhance VPC endpoint security group configuration ✅ COMPLETED

  - ✅ Updated VPC endpoint security group to ensure proper HTTPS access rules
  - ✅ Verified ECS task security group has outbound HTTPS rule to VPC endpoints
  - ✅ Added explicit security group rules for ECR service communication
  - ✅ Implemented comprehensive security group rules including DNS resolution and SMB connectivity
  - ✅ Added fallback HTTPS connectivity rule for redundancy
  - _Requirements: 2.1, 2.3_

- [x] 3. Validate and update ECS task execution role IAM permissions ✅ COMPLETED

  - ✅ Reviewed current ECR permissions in ECS task execution role
  - ✅ Confirmed all required ECR permissions are present (GetAuthorizationToken, BatchGetImage, etc.)
  - ✅ Verified S3 access permissions for image layer downloads from ECR starport bucket
  - ✅ Added comprehensive AWS service permissions (Secrets Manager, SSM)
  - ✅ **JUST ADDED**: CloudWatch Logs access permissions for comprehensive logging support
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 4. Create ECR connectivity diagnostic script

  - Write shell script to test ECR API endpoint connectivity from ECS tasks
  - Implement DNS resolution testing for ECR service endpoints
  - Add network connectivity validation for VPC endpoints
  - Create comprehensive connectivity test that can run in ECS container
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 5. Implement VPC endpoint health check utility

  - Create script to verify VPC endpoint status and configuration
  - Add validation for security group rules and route table associations
  - Implement automated checks for DNS resolution and endpoint accessibility
  - _Requirements: 4.1, 4.3_

- [-] 6. Add comprehensive logging and monitoring for ECR operations

  - Update ECS task definition to include detailed ECR operation logging
  - Add CloudWatch custom metrics for ECR pull success/failure rates
  - Implement structured logging for ECR connectivity troubleshooting
  - _Requirements: 5.1, 5.2, 5.3_

- [ ] 7. Create automated ECR connectivity validation test

  - Write integration test that validates complete ECR pull workflow
  - Implement test cases for various failure scenarios (S3 endpoint, security groups, IAM)
  - Add test runner that can be executed during deployment validation
  - _Requirements: 4.1, 4.2, 4.3_

- [ ] 8. Update deployment scripts with connectivity verification
  - Modify deployment scripts to run ECR connectivity tests before task deployment
  - Add pre-deployment validation for VPC endpoint configuration
  - Implement rollback mechanism if connectivity tests fail
  - _Requirements: 5.3, 4.3_
