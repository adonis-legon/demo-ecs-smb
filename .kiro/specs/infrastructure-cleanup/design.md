# Infrastructure Cleanup Design

## Overview

This design consolidates the infrastructure templates and deployment scripts by updating the original files to use the embedded SMB setup approach, eliminating the need for multiple file versions and S3 dependencies for the compute stack.

## Architecture

The cleanup will maintain the existing nested stack architecture while updating the compute stack to use embedded SMB setup:

```
infrastructure/
├── main-template.yaml (updated)
└── templates/
    ├── networking-stack.yaml (unchanged)
    ├── compute-stack.yaml (updated with embedded SMB)
    └── application-stack.yaml (unchanged)

scripts/
├── deploy-stack.sh (updated)
├── setup-parameters.sh (unchanged)
└── setup-nested-stacks.sh (unchanged)
```

## Components and Interfaces

### 1. Updated Compute Stack Template

**File:** `infrastructure/templates/compute-stack.yaml`

**Changes:**

- Remove `S3BucketName` parameter
- Remove S3 access policies from IAM role
- Embed complete SMB setup PowerShell script in UserData
- Keep all other functionality (EBS volume, security groups, outputs)

**Interface:**

- **Input Parameters:** Same as before except no `S3BucketName`
- **Outputs:** Same as before (instance ID, private IP, role ARN, etc.)
- **Dependencies:** VPC and security group from networking stack

### 2. Updated Main Template

**File:** `infrastructure/main-template.yaml`

**Changes:**

- Remove `S3BucketName` parameter passing to compute stack
- Keep S3 bucket parameter for networking and application stacks (they still need S3 for template storage)
- Update compute stack template reference to use standard `compute-stack.yaml`

**Interface:**

- **Input Parameters:** Same as before
- **Outputs:** Same as before
- **Dependencies:** S3 bucket for template storage (networking and application only)

### 3. Updated Deployment Script

**File:** `scripts/deploy-stack.sh`

**Changes:**

- Update to work with the new compute stack (no S3 dependency)
- Keep existing parameter validation and setup
- Maintain same command-line interface
- Add validation that embedded SMB setup is working

**Interface:**

- **Command Line:** Same as before (`--profile`, `--region`, `--ecr-uri`)
- **Outputs:** Same deployment status and stack information
- **Dependencies:** AWS CLI, CloudFormation, S3 (for template storage only)

## Data Models

### Compute Stack Parameters (Updated)

```yaml
Parameters:
  ApplicationName: String
  WindowsInstanceType: String
  SMBUsername: String
  SMBPassword: String (NoEcho)
  AvailabilityZone: String
  VPCId: String (from networking stack)
  PrivateSubnetId: String (from networking stack)
  WindowsEC2SecurityGroupId: String (from networking stack)
  # REMOVED: S3BucketName
```

### IAM Role Policies (Updated)

```yaml
Policies:
  - SSMParameterAccess (unchanged)
  - SecretsManagerAccess (unchanged)
  - CloudFormationSignal (unchanged)
  # REMOVED: S3ScriptAccess
```

### UserData Structure (Updated)

```powershell
<powershell>
# Embedded SMB Setup Script
# - Complete SMB user creation
# - Directory and share setup
# - Firewall configuration
# - Comprehensive logging
# - CloudFormation signaling
</powershell>
```

## Error Handling

### 1. Template Validation

- Validate that embedded PowerShell script syntax is correct
- Ensure CloudFormation template size stays within limits
- Verify all parameter references are valid

### 2. Deployment Error Handling

- Maintain existing CloudFormation error handling
- Add specific validation for embedded SMB setup completion
- Provide clear error messages if SMB setup fails

### 3. Rollback Strategy

- Use CloudFormation's built-in rollback capabilities
- Ensure UserData script failures don't prevent instance creation
- Log all SMB setup steps for debugging

## Testing Strategy

### 1. Template Validation Tests

```bash
# Validate updated templates
aws cloudformation validate-template --template-body file://infrastructure/templates/compute-stack.yaml
aws cloudformation validate-template --template-body file://infrastructure/main-template.yaml
```

### 2. Deployment Tests

```bash
# Test deployment with updated scripts
./scripts/deploy-stack.sh --profile test-profile --region us-east-1 --ecr-uri test-uri
```

### 3. SMB Functionality Tests

```bash
# Verify SMB share is accessible
# Test ECS task can connect to SMB share
# Validate file operations work correctly
```

### 4. Cleanup Verification

```bash
# Ensure no duplicate files remain
find . -name "*-no-s3*" | wc -l  # Should return 0
```

## Implementation Plan

### Phase 1: Update Core Templates

1. Update `infrastructure/templates/compute-stack.yaml`

   - Remove S3 parameters and policies
   - Embed SMB setup script in UserData
   - Test template validation

2. Update `infrastructure/main-template.yaml`
   - Remove S3BucketName parameter passing to compute stack
   - Test nested stack references

### Phase 2: Update Deployment Scripts

1. Update `scripts/deploy-stack.sh`
   - Remove S3 dependency for compute stack
   - Add embedded SMB setup validation
   - Test deployment process

### Phase 3: Clean Up Duplicate Files

1. Remove temporary files:
   - `infrastructure/templates/compute-stack-no-s3.yaml`
   - `infrastructure/main-template-no-s3.yaml`
   - `scripts/deploy-no-s3.sh`
   - `scripts/deploy-no-s3.ps1`
   - `scripts/diagnose-s3-issue.ps1`

### Phase 4: Validation and Testing

1. Full deployment test
2. SMB functionality verification
3. ECS application connectivity test
4. Documentation update

## Migration Strategy

### For Existing Deployments

1. **No immediate action required** - existing stacks continue to work
2. **For updates** - use updated templates that will replace compute stack with embedded SMB setup
3. **For new deployments** - use consolidated templates from the start

### Deployment Command

```bash
# Same command as before - no changes needed
./scripts/deploy-stack.sh --profile cn-ps-assistant-dev --region us-east-1 --ecr-uri 481123212323.dkr.ecr.us-east-1.amazonaws.com/scheduled-file-writer:latest
```

## Benefits

1. **Simplified Structure** - Single set of templates and scripts
2. **No S3 Dependency** - Embedded SMB setup eliminates S3 access issues
3. **Backward Compatible** - Same interfaces and outputs
4. **Easier Maintenance** - No duplicate files to keep in sync
5. **Faster Deployment** - No external script downloads
6. **Better Reliability** - Eliminates network/permission issues with S3 access

## Risks and Mitigations

### Risk 1: Template Size Limits

- **Risk:** Embedded PowerShell script might make template too large
- **Mitigation:** Optimize script size, use CloudFormation template size validation

### Risk 2: UserData Script Failures

- **Risk:** Embedded script might fail without clear error reporting
- **Mitigation:** Comprehensive logging, CloudFormation signaling, error handling

### Risk 3: Breaking Existing Deployments

- **Risk:** Updates might break existing infrastructure
- **Mitigation:** Thorough testing, backward compatibility validation, rollback plan

## Success Criteria

1. ✅ Single `compute-stack.yaml` file with embedded SMB setup
2. ✅ Single `main-template.yaml` file with updated references
3. ✅ Single `deploy-stack.sh` script with same interface
4. ✅ No duplicate `*-no-s3.*` files in repository
5. ✅ SMB functionality works identically to original implementation
6. ✅ ECS application can connect to SMB share successfully
7. ✅ Deployment time is same or faster than original approach
