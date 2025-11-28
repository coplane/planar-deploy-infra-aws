# Terraform Planar AWS Infrastructure

This Terraform configuration deploys a complete AWS infrastructure stack for the Planar application, including containerized application hosting, managed database, object storage, and networking components.

## Architecture Overview

The infrastructure follows a serverless and containerized architecture pattern, leveraging AWS managed services for scalability, reliability, and operational simplicity. The solution is designed to run in private subnets with internal load balancing, ensuring security and network isolation.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Route53 DNS                          │
│              (app-name-stage.base-domain.com)               │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Load Balancer (ALB)                │
│                    (Internal, HTTPS)                        │
│              ┌──────────────────────────────┐               │
│              │  ACM Certificate (TLS/SSL)   │               │
│              └──────────────────────────────┘               │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              ECS Fargate Service                            │
│  ┌────────────────────────────────────────────────────┐     │
│  │  Container: planar-app (Port 8000)                 │     │
│  │  - Pulls from private container registry           │     │
│  │  - Accesses secrets via Secrets Manager            │     │
│  │  - Writes logs to CloudWatch                       │     │
│  └────────────────────────────────────────────────────┘     │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┬───────────────────┐
        │                               │                   │
        ▼                               ▼                   ▼
┌───────────────┐              ┌───────────────┐   ┌───────────────┐
│  RDS Aurora   │              │   S3 Bucket   │   │   Bedrock     │
│  PostgreSQL   │              │  (App Data)   │   │               │
│ Serverless v2 │              │               │   │   Anthropic   │
│               │              │  - Versioned  │   │   Sonet 4.5   │
│ - Auto-scaling│              │  - Encrypted  │   │   Opus 4.5    │
│ - Multi-AZ    │              │  - CORS       │   │               │
└───────────────┘              └───────────────┘   └───────────────┘
```

## Main Components

### 1. **ECS (Elastic Container Service)**
- **Cluster**: Fargate-based ECS cluster with Container Insights enabled
- **Service**: Runs containerized Planar application
- **Task Definition**: 
  - CPU: Configurable (default: 2048 = 2 vCPU)
  - Memory: Configurable (default: 4096 MB)
  - Network: `awsvpc` mode in private subnets
  - Container Port: 8000
- **Deployment Strategy**: Rolling deployment (50-200% capacity during updates)
- **Logging**: CloudWatch Logs with 14-day retention

### 2. **Application Load Balancer (ALB)**
- **Type**: Internal Application Load Balancer
- **Protocol**: HTTPS (443) with HTTP (80) redirect
- **SSL/TLS**: Managed by ACM certificate
- **Health Checks**: 
  - Path: `/planar/v1/health`
  - Interval: 30 seconds
  - Healthy threshold: 2
  - Unhealthy threshold: 10
- **Deletion Protection**: Enabled for production, disabled for other stages

### 3. **RDS Aurora PostgreSQL**
- **Engine**: Aurora PostgreSQL Serverless v2
- **Version**: 16.6
- **Scaling**: 
  - Min capacity: 0.5 ACU (configurable)
  - Max capacity: 2.0 ACU (configurable)
- **Features**:
  - Automatic backups (configurable retention, default 7 days)
  - Encryption at rest enabled
  - HTTP endpoint enabled (Data API)
  - Performance Insights enabled
  - Enhanced monitoring (60-second intervals)
- **Deletion Protection**: Enabled for production
- **Final Snapshots**: Created for production before deletion

### 4. **S3 Bucket**
- **Purpose**: Application data storage
- **Features**:
  - Versioning enabled
  - Server-side encryption (AES256)
  - Public access blocked
  - CORS configuration for web access
  - SSL-only access policy
- **Naming**: `planar-{stage}-{app_name}-{random_suffix}`

### 5. **DNS & Certificate Management**
- **Route53**: DNS records for application domain
- **ACM Certificate**: SSL/TLS certificate with DNS validation
- **Domain Pattern**: `{app_name}-{stage}.{base_domain_name}`

### 6. **Secrets Management**
- **Registry Credentials**: Stored in Secrets Manager for container image pull authentication
- **Database Credentials**: Managed by RDS (automatically rotated master password)
- **Custom Secrets**: Application-specific secrets storage
- **Recovery Window**: 30 days for production, immediate deletion for other stages

### 7. **IAM Roles & Policies**
- **ECS Execution Role**: 
  - Pulls container images from private registry
  - Accesses registry credentials from Secrets Manager
  - Writes logs to CloudWatch
- **ECS Task Role**: 
  - Accesses Secrets Manager (DB and custom secrets)
  - Full S3 access to application bucket
  - **AWS Bedrock Access**: 
    - `bedrock:InvokeModel` - Invoke foundation models
    - `bedrock:InvokeModelWithResponseStream` - Stream model responses
    - `bedrock:ListFoundationModels` - List available models
    - `bedrock:GetFoundationModel` - Get model details
    - Currently configured with wildcard resource (`*`)
- **RDS Monitoring Role**: Enhanced monitoring for Aurora cluster

### 8. **Security Groups**
- **ALB Security Group**: 
  - Ingress: HTTP (80) and HTTPS (443) from VPC CIDR
  - Egress: Port 8000 to VPC CIDR
- **ECS Tasks Security Group**: 
  - Ingress: Port 8000 from ALB security group
  - Egress: All traffic (0.0.0.0/0)
- **RDS Security Group**: 
  - Ingress: PostgreSQL (5432) from ECS tasks security group
  - Egress: All traffic

### 9. **Networking**
- **VPC**: Uses existing VPC (provided via variable). Tested with NAT gateway for internet access.
- **Subnets**: Deploys to private subnets (provided via variable)
- **Network Mode**: `awsvpc` (each task gets its own ENI)
- **Public IP**: Disabled (ECS tasks run in private subnets). ALB needs *public* subnets (alb_subnets variable) when access via internet is required.

### 10. **AWS Bedrock Integration**
- **Purpose**: AI/ML foundation model access for application features
- **Configuration**: 
  - IAM permissions granted to ECS task role
  - No explicit Bedrock resources created (uses AWS managed service)
  - Application accesses Bedrock via AWS SDK using task role credentials
- **Permissions**: 
  - Model invocation (synchronous and streaming)
  - Model discovery and metadata access
- **Access Pattern (public endpoints via NAT)**:
  - ECS tasks run in private subnets.
  - Outbound traffic to Bedrock uses the public Bedrock endpoints.
  - Traffic egresses via NAT gateway from the private subnets.
  - No VPC endpoint for Bedrock is configured in this architecture.

## Dependencies

### External Dependencies (Must be provided)
1. **VPC**: Existing VPC ID where resources will be deployed
2. **Subnets**: List of private subnet IDs (minimum 2 recommended for high availability)
3. **Route53 Hosted Zone**: Existing hosted zone for the base domain
4. **Container Registry**: 
   - Private container registry (e.g., GHCR, Docker Hub, ECR)
   - Registry credentials (username/password or token)
   - Container image must be available in the registry
5. **Internet Access**:
   - https://auth-api.coplane.com/sso/jwks/* - required access to WorkOS API to download JWT public keys
   - https://api.coplane.com/v1/dir_sync/* - *optional* CoPlane Backend REST API to sync list of users and groups from your IDP

### AWS Service Dependencies
- **AWS Account**: Active AWS account with appropriate permissions
- **AWS Profile/Region**: Configured AWS credentials and region
- **AWS Bedrock**: 
  - Bedrock service must be enabled in the target AWS region
- **IAM Permissions**: User/role deploying must have permissions to create:
  - ECS clusters, services, task definitions
  - ALB, target groups, listeners
  - RDS clusters and instances
  - S3 buckets and policies
  - Route53 records
  - ACM certificates
  - Secrets Manager secrets
  - IAM roles and policies
  - Security groups
  - CloudWatch log groups

### Terraform Dependencies
- **Terraform**: Version >= 1.0
- **AWS Provider**: Version ~> 5.0
- **Random Provider**: Version ~> 3.1

## CI/CD

#### Manual Deployment
```bash
# Initial deployment
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

```

### Recommended CI/CD Integration

While not part of the scope of this template, the following CI/CD patterns are recommended:

 **GitHub Actions / GitLab CI
   - Trigger on git push/merge to main branch
   - Run Docker Image build and push to private container repo
   - Run `terraform apply` for main branch

## Usage

### Prerequisites
1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.13.4 installed
3. Access to the target VPC and subnets
4. Route53 hosted zone for the base domain
5. Container image available in the specified registry
6. **AWS Bedrock enabled**: 
   - Bedrock service must be enabled in the target AWS region
   - Anthropic (Sonet/Opus) models must be enabled (some require opt-in via AWS Console)

### Outputs

After deployment, Terraform outputs include:
- Load balancer DNS name and zone ID
- ECS cluster and service names
- RDS cluster endpoints
- S3 bucket name and ARN
- Secret ARNs
- Certificate ARN
- Domain name

Access outputs with:
```bash
terraform output
terraform output -json  # JSON format
terraform output <output_name>  # Specific output
```

## Variables Reference

See `variables.tf` for complete variable documentation. Key variables:

- `app_name`: Application name (used in resource naming)
- `stage`: Environment stage (dev, staging, prod)
- `vpc_id`: VPC ID where resources will be created
- `subnets`: List of your private subnet IDs
- `alb_subnets`: List of your public subnet IDs
- `base_domain_name`: Base domain for Route53
- `container_registry_url`: Container registry base URL
- `container_image_name`: Container image name/path
- `container_image_tag`: Image tag to deploy
- `container_cpu`: CPU units (1024 = 1 vCPU)
- `container_memory`: Memory in MB
- `desired_count`: Number of ECS tasks
- `aurora_min_capacity`: Minimum Aurora capacity (ACUs)
- `aurora_max_capacity`: Maximum Aurora capacity (ACUs)

## Security Considerations

- All compute resources are deployed in private subnets
- ALB is internet-facing by default
- Database is only accessible from ECS tasks
- S3 bucket has public access blocked
- Secrets are stored in AWS Secrets Manager
- All inter-service communication uses security groups
- SSL/TLS encryption for all external communication
- Database encryption at rest enabled
- **AWS Bedrock**: 
  - IAM-based access control (currently uses wildcard - see recommendations)
  - All API calls encrypted in transit (HTTPS)
  - No data stored by AWS Bedrock (stateless API)
  - **Note**: Consider restricting Bedrock permissions to specific models/regions for enhanced security

## Cost Estimation

Approximate monthly costs (us-east-1, staging environment):
- ECS Fargate (2 vCPU, 4GB): ~$60-80/month
- ALB: ~$20-25/month
- Aurora Serverless v2 (0.5-2 ACU): ~$50-150/month (usage-dependent)
- S3: Variable based on storage and requests
- CloudWatch Logs: Variable based on log volume
- Route53: ~$0.50/month per hosted zone
- Secrets Manager: ~$0.40/month per secret
- **AWS Bedrock**: Variable based on usage
  - Pay-per-use pricing model
  - Costs depend on:
    - Model type (Claude)
    - Input/output tokens processed
    - Number of API calls
    - Region

**Total estimated**: ~$130-300/month for staging (excluding data transfer and Bedrock usage)

**Note**: Bedrock costs can vary significantly based on application usage patterns. For production workloads with heavy AI/ML usage, Bedrock costs may exceed infrastructure costs.

## Support

For issues or questions:
- Vendor Contact: support@coplane.com
- Framework: Planar v0.17

## License
Apache License 2.0

