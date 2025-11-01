# ECR-Based Deployment Guide

## Overview

This project now supports a modern, production-ready deployment approach using **Amazon ECR (Elastic Container Registry)** and **Docker containers**. This approach separates infrastructure provisioning from application deployment, following DevOps best practices.

## Architecture Improvements

### Old Approach (Traditional)
```
User Data Script → Copy entire code → Install dependencies → Run app
```
**Issues:**
- Code embedded in user data scripts
- Hard to update applications
- No version control for deployments
- Slow instance startup

### New Approach (ECR-Based)
```
1. Build Docker images locally
2. Push to ECR
3. Terraform creates infrastructure
4. EC2 instances pull images from ECR
5. Run containers
```
**Benefits:**
- ✅ Separation of concerns
- ✅ Version control with image tags
- ✅ Fast deployments and rollbacks
- ✅ Consistent environments
- ✅ Easy updates without infrastructure changes

## Deployment Workflow

### Phase 1: Build and Push Docker Images

```bash
# Build and push images to ECR
./scripts/build-and-push.sh [tag]

# Example with version tag
./scripts/build-and-push.sh v1.0.0

# Or use 'latest' (default)
./scripts/build-and-push.sh
```

**What happens:**
1. Script gets AWS account ID and region
2. Checks if ECR repositories exist, creates them if needed
3. Builds Docker images for frontend and backend
4. Pushes images to ECR with specified tag

### Phase 2: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform (first time only)
terraform init

# Deploy with specific image tag
terraform apply -var="image_tag=v1.0.0"

# Or use latest
terraform apply
```

**What happens:**
1. Creates ECR repositories
2. Provisions VPC, subnets, security groups
3. Creates RDS database
4. Launches EC2 instances
5. EC2 user data scripts:
   - Install Docker
   - Login to ECR
   - Pull specified image
   - Run container with environment variables

## Complete Deployment Steps

### Step 1: Configure AWS Credentials

```bash
aws configure
```

### Step 2: Create SSH Key Pair

```bash
aws ec2 create-key-pair \
  --key-name 3tier-app-key \
  --query 'KeyMaterial' \
  --output text > 3tier-app-key.pem

chmod 400 3tier-app-key.pem
```

### Step 3: Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region   = "us-east-1"
project_name = "3tier-web-app"
db_password  = "YourStrongPassword123!"  # CHANGE THIS!

# ECR deployment settings
use_ecr_deployment = true  # Use ECR-based deployment
image_tag          = "latest"
```

### Step 4: Build and Push Docker Images

```bash
# The script will automatically create ECR repositories if they don't exist
chmod +x scripts/build-and-push.sh
./scripts/build-and-push.sh v1.0.0
```

**Note:** The `build-and-push.sh` script now automatically creates ECR repositories if they don't exist, so you don't need to run Terraform first!

### Step 5: Deploy Full Infrastructure

```bash
cd terraform
terraform apply -var="image_tag=v1.0.0"
```

### Step 6: Access Application

```bash
# Get ALB URL
terraform output alb_url

# Open in browser
open $(terraform output -raw alb_url)
```

## Updating Applications

### Option 1: Update Code and Redeploy

```bash
# 1. Make code changes in app/frontend or app/backend

# 2. Build and push new images
./scripts/build-and-push.sh v1.1.0

# 3. Update EC2 instances to use new image
cd terraform
terraform apply -var="image_tag=v1.1.0"
```

### Option 2: Manual Container Update (Quick)

```bash
# SSH to EC2 instance
ssh -i 3tier-app-key.pem ec2-user@<instance-ip>

# Pull new image
sudo docker pull <ecr-repo-url>:v1.1.0

# Restart service
sudo systemctl restart frontend-container.service
```

## Image Tag Strategy

### Recommended Tagging

```bash
# Development
./scripts/build-and-push.sh dev

# Staging
./scripts/build-and-push.sh staging

# Production with version
./scripts/build-and-push.sh v1.0.0

# Latest (default)
./scripts/build-and-push.sh latest
```

### Multiple Tags

The build script automatically creates two tags:
- Your specified tag (e.g., `v1.0.0`)
- `latest` tag

This allows:
```bash
# Deploy specific version
terraform apply -var="image_tag=v1.0.0"

# Or always use latest
terraform apply -var="image_tag=latest"
```

## ECR Repository Management

### View Images in ECR

```bash
# List frontend images
aws ecr list-images \
  --repository-name 3tier-web-app-frontend \
  --query 'imageIds[*].imageTag' \
  --output table

# List backend images
aws ecr list-images \
  --repository-name 3tier-web-app-backend \
  --query 'imageIds[*].imageTag' \
  --output table
```

### Delete Old Images

```bash
# Delete specific image
aws ecr batch-delete-image \
  --repository-name 3tier-web-app-frontend \
  --image-ids imageTag=old-tag
```

**Note:** Lifecycle policies automatically keep only the last 5 tagged images.

## Rollback Strategy

### Rollback to Previous Version

```bash
# 1. Identify previous working version
aws ecr list-images --repository-name 3tier-web-app-frontend

# 2. Deploy previous version
cd terraform
terraform apply -var="image_tag=v1.0.0"
```

### Emergency Rollback

```bash
# SSH to instances and manually update
ssh -i 3tier-app-key.pem ec2-user@<instance-ip>

# Pull previous image
sudo docker pull <ecr-repo>:v1.0.0

# Update systemd service file
sudo nano /etc/systemd/system/frontend-container.service
# Change image tag in ExecStart line

# Restart service
sudo systemctl daemon-reload
sudo systemctl restart frontend-container.service
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to ECR
        run: |
          aws ecr get-login-password --region us-east-1 | \
          docker login --username AWS --password-stdin \
          ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
      
      - name: Build and push images
        run: |
          ./scripts/build-and-push.sh ${{ github.sha }}
      
      - name: Deploy to AWS
        run: |
          cd terraform
          terraform init
          terraform apply -auto-approve -var="image_tag=${{ github.sha }}"
```

## Monitoring and Logs

### View Container Logs

```bash
# SSH to instance
ssh -i 3tier-app-key.pem ec2-user@<instance-ip>

# View container logs
sudo docker logs -f frontend

# View systemd service logs
sudo journalctl -u frontend-container.service -f
```

### Check Container Status

```bash
# List running containers
sudo docker ps

# Check service status
sudo systemctl status frontend-container.service
```

## Troubleshooting

### Issue: Image Pull Failed

**Symptoms:**
```
Error response from daemon: pull access denied
```

**Solution:**
```bash
# Check IAM role has ECR permissions
aws iam get-role-policy --role-name 3tier-web-app-ec2-role --policy-name 3tier-web-app-ec2-policy

# Verify ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

### Issue: Container Won't Start

**Check logs:**
```bash
sudo journalctl -u frontend-container.service -n 50
sudo docker logs frontend
```

**Common causes:**
- Wrong environment variables
- Database not accessible
- Port already in use

### Issue: Build Script Fails

**Error:** `Terraform state not found`

**Solution:**
```bash
# Create ECR repositories first
cd terraform
terraform apply -target=aws_ecr_repository.frontend -target=aws_ecr_repository.backend
```

## Comparison: Traditional vs ECR Deployment

| Feature | Traditional | ECR-Based |
|---------|------------|-----------|
| **Deployment Speed** | Slow (install deps) | Fast (pull image) |
| **Updates** | Recreate instances | Update containers |
| **Rollback** | Difficult | Easy (change tag) |
| **Version Control** | No | Yes (image tags) |
| **Consistency** | Variable | Guaranteed |
| **CI/CD Ready** | No | Yes |
| **Cost** | Same | Same |

## Security Considerations

### ECR Security

1. **Image Scanning**: Enabled automatically
   ```bash
   # View scan results
   aws ecr describe-image-scan-findings \
     --repository-name 3tier-web-app-frontend \
     --image-id imageTag=latest
   ```

2. **Encryption**: AES256 encryption at rest

3. **IAM Permissions**: Least privilege access
   - EC2 can only pull images
   - Cannot push or delete

### Container Security

1. **Non-root user**: Run containers as non-root (recommended)
2. **Read-only filesystem**: Mount as read-only where possible
3. **Resource limits**: Set CPU and memory limits

## Cost Optimization

### ECR Costs

- **Storage**: $0.10 per GB/month
- **Data Transfer**: Free to EC2 in same region

**Typical usage:**
- Frontend image: ~200 MB
- Backend image: ~300 MB
- 5 versions each: ~2.5 GB
- **Cost**: ~$0.25/month

### Optimization Tips

1. **Lifecycle policies**: Already configured (keep last 5 images)
2. **Multi-stage builds**: Reduce image size
3. **Layer caching**: Faster builds

## Best Practices

### 1. Image Tagging

```bash
# Use semantic versioning
./scripts/build-and-push.sh v1.2.3

# Include git commit
./scripts/build-and-push.sh $(git rev-parse --short HEAD)

# Environment-specific
./scripts/build-and-push.sh prod-v1.2.3
```

### 2. Testing Before Deployment

```bash
# Test locally first
cd app
docker-compose up -d

# Run tests
curl http://localhost:8000/health

# Then push to ECR
./scripts/build-and-push.sh v1.2.3
```

### 3. Gradual Rollout

```bash
# Deploy to one instance first
# Update specific instance manually
# Monitor for issues
# Then deploy to all instances
terraform apply -var="image_tag=v1.2.3"
```

### 4. Backup Before Updates

```bash
# Note current version
terraform output

# Take RDS snapshot
aws rds create-db-snapshot \
  --db-instance-identifier 3tier-web-app-db \
  --db-snapshot-identifier pre-update-$(date +%Y%m%d)
```

## Migration from Traditional Approach

If you're currently using the traditional approach:

```bash
# 1. Set use_ecr_deployment to true
cd terraform
nano terraform.tfvars
# Add: use_ecr_deployment = true

# 2. Create ECR repositories
terraform apply -target=aws_ecr_repository.frontend -target=aws_ecr_repository.backend

# 3. Build and push images
cd ..
./scripts/build-and-push.sh v1.0.0

# 4. Update EC2 instances
cd terraform
terraform apply -var="image_tag=v1.0.0"
```

## Summary

The ECR-based deployment approach provides:

✅ **Faster deployments** - Pull images instead of building on instances  
✅ **Version control** - Tag and track every deployment  
✅ **Easy rollbacks** - Switch to any previous version  
✅ **CI/CD ready** - Integrate with any CI/CD pipeline  
✅ **Production-grade** - Industry standard approach  

## Next Steps

1. **Set up CI/CD**: Automate builds and deployments
2. **Add monitoring**: CloudWatch Container Insights
3. **Implement blue-green**: Zero-downtime deployments
4. **Add auto-scaling**: Scale based on metrics

---

**Ready to deploy? Start with Step 1!** 🚀
