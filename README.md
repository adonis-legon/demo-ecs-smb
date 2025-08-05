# Scheduled File Writer

A Java Spring Boot console application that connects to an SMB/CIFS file share to generate and write random files on a scheduled basis. The application is deployed on AWS using a modular CloudFormation nested stack architecture.

## Project Structure

```
scheduled-file-writer/
├── src/                                    # Java application source code
│   ├── main/
│   │   ├── java/
│   │   └── resources/
│   │       └── application.properties
│   └── test/
│       └── java/
├── infrastructure/                         # CloudFormation infrastructure
│   ├── templates/                          # Nested stack templates
│   │   ├── networking-stack.yaml          # VPC, subnets, security groups
│   │   ├── compute-stack.yaml             # Windows EC2 with embedded SMB setup
│   │   └── application-stack.yaml         # ECS cluster, task definitions
│   ├── config/
│   │   └── s3-bucket.conf                 # S3 bucket configuration
│   └── main-template.yaml                 # Main orchestration template
├── scripts/                               # Essential deployment scripts
│   ├── setup-parameters.sh               # SSM parameters and secrets setup
│   ├── setup-nested-stacks.sh            # S3 bucket setup and template upload
│   ├── deploy-stack.sh                   # CloudFormation deployment
│   ├── destroy-stack.sh                  # Stack deletion
│   └── destroy-nested-stacks.sh          # Complete infrastructure cleanup
├── local-dev/                            # Local development environment
│   ├── samba-config/                     # Local SMB server configuration
│   └── .env.local                        # Local environment variables
├── target/                               # Maven build artifacts
├── pom.xml                               # Maven configuration
├── Dockerfile                            # Container image definition
├── docker-compose.yml                   # Local development setup
├── build-docker.sh                      # Docker build script
├── run-local.sh                         # Local development runner
├── .dockerignore
├── .env
└── README.md
```

## Dependencies

- **JDK 21**: Required Java version
- **Spring Boot 3.5.4**: Latest stable version with security updates
- **JCIFS 1.3.17**: SMB/CIFS protocol support for file share connectivity
- **AWS SDK 2.30.29**: Latest version for SSM Parameter Store and Secrets Manager integration
- **JUnit 5**: Testing framework

## Build and Run

### Maven Build

```bash
mvn clean package
```

### Docker Build

```bash
docker build -t scheduled-file-writer .
```

### Run Application

```bash
java -jar target/scheduled-file-writer-1.0.0.jar
```

## Configuration

The application is configured through environment variables:

- `FILE_SHARE_HOST`: SMB file share host address
- `FILE_SHARE_PATH`: Target directory path on the share
- `SMB_USERNAME`: SMB authentication username
- `SMB_PASSWORD`: SMB authentication password
- `SMB_DOMAIN`: Windows domain or workgroup
- `CONNECTION_TIMEOUT`: Connection timeout in seconds

## AWS Deployment

This application is designed to run as an ECS task on AWS, with infrastructure provisioned through a modular CloudFormation nested stack architecture.

### Nested Stack Architecture

The infrastructure is organized into four logical components to improve maintainability and overcome CloudFormation template size limits:

#### 🏗️ Main Template (`main-template.yaml`)

- Orchestrates the deployment of all nested stacks
- Manages parameter passing between stacks
- Aggregates outputs from all nested components
- Handles dependency ordering (Networking → Compute → Application)

#### 🌐 Networking Stack (`networking-stack.yaml`)

- **VPC and Subnets**: Private subnet in specified availability zone
- **Security Groups**: ECS task security group, Windows EC2 security group, VPC endpoint security group
- **VPC Endpoints**: ECR (API & DKR), CloudWatch Logs, SSM, EC2, KMS, Secrets Manager, CloudFormation
- **Outputs**: VPC ID, subnet IDs, security group IDs for cross-stack references

#### 💻 Compute Stack (`compute-stack.yaml`)

- **Windows EC2 Instance**: t3.micro instance for SMB file share hosting
- **EBS Volume**: 20GB gp3 volume attached to Windows instance
- **IAM Roles**: Instance profile with SSM and CloudWatch permissions
- **Outputs**: Instance ID, private IP address for application connectivity

#### 🚀 Application Stack (`application-stack.yaml`)

- **ECS Cluster**: Fargate cluster for running the scheduled file writer
- **Task Definition**: Container configuration with SMB connectivity
- **EventBridge Rule**: Scheduled execution (configurable cron expression)
- **CloudWatch Logs**: Application logging and monitoring
- **IAM Roles**: Task execution and task roles with required permissions

## 🚀 Complete Deployment Guide

Follow these steps in order for a complete deployment from scratch:

### Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed and running
- JDK 21 and Maven installed
- AWS ECR repository created (or use the build script to create it)

### Step 1: Build and Push Docker Image

Build the application and push it to Amazon ECR:

```bash
# Build, test, and push to ECR (creates repository if it doesn't exist)
./build-docker.sh --push --profile YOUR_AWS_PROFILE --region YOUR_REGION

# Alternative: Specify custom ECR registry
./build-docker.sh --push --profile YOUR_AWS_PROFILE --ecr-registry YOUR_ACCOUNT_ID.dkr.ecr.YOUR_REGION.amazonaws.com
```

**What this does:**

- Runs Maven tests to ensure code quality
- Builds Docker image with proper versioning
- Creates ECR repository if it doesn't exist
- Pushes image to ECR with latest tag

### Step 2: Setup SSM Parameters

Configure all required parameters and secrets:

```bash
# Create SSM parameters and Secrets Manager entries
./scripts/setup-parameters.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION
```

**What this does:**

- Prompts for network configuration (VPC CIDR, subnet, AZ)
- Generates S3 bucket name for CloudFormation templates
- Collects SMB credentials securely
- Creates SSM parameters for all configuration values
- Stores SMB credentials in AWS Secrets Manager

### Step 3: Setup Nested Stacks Infrastructure

Prepare S3 bucket and upload CloudFormation templates:

```bash
# Create S3 bucket and upload all templates
./scripts/setup-nested-stacks.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION
```

**What this does:**

- Retrieves S3 bucket name from SSM Parameter Store
- Creates S3 bucket with versioning and encryption
- Uploads all CloudFormation templates to S3
- Validates template syntax and cross-stack references

### Step 4: Deploy CloudFormation Stack

Deploy the complete infrastructure:

```bash
# Deploy the complete nested stack architecture
./scripts/deploy-stack.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION --ecr-uri YOUR_ECR_URI
```

**Example with specific ECR URI:**

```bash
./scripts/deploy-stack.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION --ecr-uri 123456789012.dkr.ecr.us-east-1.amazonaws.com/scheduled-file-writer:latest
```

**What this does:**

- Validates all templates and parameters
- Deploys networking stack (VPC, security groups, VPC endpoints)
- Deploys compute stack (Windows EC2 with embedded SMB setup)
- Deploys application stack (ECS cluster, task definition, EventBridge)
- Configures automatic scheduling (every 5 minutes by default)

### Step 5: Verify Deployment

After deployment completes, verify the setup:

```bash
# Check ECS task logs
aws logs tail /ecs/scheduled-file-writer --follow --profile YOUR_AWS_PROFILE --region YOUR_REGION

# Verify SMB share accessibility (from Windows EC2 instance)
aws ssm start-session --target INSTANCE_ID --profile YOUR_AWS_PROFILE --region YOUR_REGION
```

### Step 6: Cleanup (When Done)

To completely remove all resources:

```bash
# Option 1: Destroy just the CloudFormation stack (keeps S3 bucket)
./scripts/destroy-stack.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION

# Option 2: Complete cleanup including S3 bucket and templates
./scripts/destroy-nested-stacks.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION
```

## 📋 Quick Reference Commands

### Development Workflow

```bash
# 1. Build and push image
./build-docker.sh --push --profile YOUR_AWS_PROFILE

# 2. Setup parameters (first time only)
./scripts/setup-parameters.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION

# 3. Setup infrastructure (first time only)
./scripts/setup-nested-stacks.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION

# 4. Deploy/update stack
./scripts/deploy-stack.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION --ecr-uri YOUR_ECR_URI
```

### Troubleshooting

```bash
# Check stack status
aws cloudformation describe-stacks --stack-name scheduled-file-writer-stack --profile YOUR_AWS_PROFILE

# View stack events
aws cloudformation describe-stack-events --stack-name scheduled-file-writer-stack --profile YOUR_AWS_PROFILE

# Check ECS task status
aws ecs list-tasks --cluster scheduled-file-writer-cluster --profile YOUR_AWS_PROFILE
```

### Legacy Deployment Process (Deprecated)

The following section is maintained for reference but uses the new streamlined approach above:

4. **Deployment Complete**:

   The stack deployment includes built-in validation and will automatically:

   - Create Windows EC2 instance with embedded SMB setup
   - Configure ECS cluster and task definitions
   - Set up EventBridge scheduling for automated execution

### Benefits of Nested Stack Architecture

- **✅ Size Limit Resolution**: Each template is well under CloudFormation's 51,200 character limit
- **🔧 Improved Maintainability**: Resources are logically grouped and easier to manage
- **🔄 Modular Updates**: Individual stacks can be updated independently
- **🚀 Parallel Development**: Teams can work on different infrastructure components simultaneously
- **🛡️ Better Error Isolation**: Failures are contained to specific resource groups
- **📊 Enhanced Validation**: Comprehensive pre-deployment validation prevents common issues
- **♻️ Reusability**: Individual stacks can be reused across different environments

### Infrastructure Cleanup Options

Choose the appropriate cleanup method based on your needs:

#### Option 1: Keep Templates and Parameters (Recommended for Development)

```bash
# Destroys only the CloudFormation stack, keeps S3 bucket and SSM parameters
./scripts/destroy-stack.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION
```

#### Option 2: Complete Cleanup (Production/Final Cleanup)

```bash
# Destroys everything: stack, S3 bucket, templates, and SSM parameters
./scripts/destroy-nested-stacks.sh --profile YOUR_AWS_PROFILE --region YOUR_REGION

# Optional: Also remove ECR repository
aws ecr delete-repository --repository-name scheduled-file-writer --force --profile YOUR_AWS_PROFILE --region YOUR_REGION
```

#### Option 3: Manual Cleanup (Troubleshooting)

```bash
# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name scheduled-file-writer-stack --profile YOUR_AWS_PROFILE --region YOUR_REGION

# Delete S3 bucket contents and bucket
aws s3 rm s3://YOUR_BUCKET_NAME --recursive --profile YOUR_AWS_PROFILE
aws s3 rb s3://YOUR_BUCKET_NAME --profile YOUR_AWS_PROFILE --region YOUR_REGION

# Delete SSM parameters
aws ssm delete-parameters --names $(aws ssm get-parameters-by-path --path "/scheduled-file-writer" --query "Parameters[].Name" --output text --profile YOUR_AWS_PROFILE --region YOUR_REGION) --profile YOUR_AWS_PROFILE --region YOUR_REGION

# Delete Secrets Manager secret
aws secretsmanager delete-secret --secret-id scheduled-file-writer/smb-credentials --force-delete-without-recovery --profile YOUR_AWS_PROFILE --region YOUR_REGION
```

For detailed setup instructions, see [infrastructure/NESTED-STACKS-SETUP.md](infrastructure/NESTED-STACKS-SETUP.md).
