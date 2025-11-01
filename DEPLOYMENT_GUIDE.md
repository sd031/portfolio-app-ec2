# Deployment Guide - 3-Tier Web Application on AWS

## Overview
This guide walks you through deploying a production-ready 3-tier web application on AWS using Terraform.

## Architecture Diagram

```
Internet
    |
    v
Application Load Balancer (Public Subnets)
    |
    v
Frontend EC2 Instances (Public Subnets)
    |
    v
Backend EC2 Instances (Private Subnets)
    |
    v
RDS MySQL Database (Database Subnets)
```

## Security Architecture

### Network Layers
1. **Public Subnet**: ALB, NAT Gateway, Frontend EC2
2. **Private Subnet**: Backend EC2 (no direct internet access)
3. **Database Subnet**: RDS MySQL (isolated)

### Security Groups
- **ALB SG**: Allows HTTP/HTTPS from internet
- **Frontend SG**: Allows traffic only from ALB
- **Backend SG**: Allows traffic only from Frontend
- **Database SG**: Allows MySQL only from Backend

### IAM Roles
- EC2 instances use IAM roles for AWS service access
- No hardcoded credentials
- SSM Session Manager enabled for secure access

## Prerequisites

### 1. AWS Account Setup
- Active AWS account with appropriate permissions
- IAM user with programmatic access
- Permissions needed:
  - EC2 (full access)
  - VPC (full access)
  - RDS (full access)
  - IAM (role creation)
  - CloudWatch (logs and metrics)

### 2. Local Environment
```bash
# Install AWS CLI
brew install awscli  # macOS
# or
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Terraform
brew install terraform  # macOS
# or
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installations
aws --version
terraform --version
```

## Step-by-Step Deployment

### Step 1: Configure AWS Credentials

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json)

Verify configuration:
```bash
aws sts get-caller-identity
```

### Step 2: Create SSH Key Pair

```bash
# Create key pair in AWS
aws ec2 create-key-pair \
  --key-name 3tier-app-key \
  --query 'KeyMaterial' \
  --output text > 3tier-app-key.pem

# Set proper permissions
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
environment  = "dev"
project_name = "3tier-web-app"

# Network Configuration
vpc_cidr                = "10.0.0.0/16"
public_subnet_cidrs     = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs    = ["10.0.11.0/24", "10.0.12.0/24"]
database_subnet_cidrs   = ["10.0.21.0/24", "10.0.22.0/24"]

# EC2 Configuration
instance_type = "t3.micro"
key_name      = "3tier-app-key"

# Database Configuration
db_instance_class = "db.t3.micro"
db_name           = "appdb"
db_username       = "admin"
db_password       = "YourStrongPassword123!"  # CHANGE THIS!

# Security
allowed_cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production
```

**Important**: Change the `db_password` to a strong, unique password!

### Step 4: Initialize Terraform

```bash
terraform init
```

This will:
- Download required providers (AWS)
- Initialize backend configuration
- Prepare working directory

### Step 5: Review Infrastructure Plan

```bash
terraform plan
```

Review the resources that will be created:
- VPC with 6 subnets (2 public, 2 private, 2 database)
- Internet Gateway
- 2 NAT Gateways
- Route tables
- Security groups
- 2 Frontend EC2 instances
- 2 Backend EC2 instances
- Application Load Balancer
- RDS MySQL instance
- IAM roles and policies

### Step 6: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

**Deployment time**: Approximately 10-15 minutes

The longest operations:
- RDS instance creation (~8-10 minutes)
- NAT Gateway allocation (~3-5 minutes)
- EC2 instance initialization (~2-3 minutes)

### Step 7: Retrieve Outputs

After successful deployment:

```bash
# Get ALB DNS name
terraform output alb_dns_name

# Get ALB URL
terraform output alb_url

# Get all outputs
terraform output
```

### Step 8: Access the Application

```bash
# Get the application URL
ALB_URL=$(terraform output -raw alb_url)
echo "Application URL: $ALB_URL"

# Open in browser or test with curl
curl $ALB_URL/health
```

Wait 2-3 minutes for:
- EC2 instances to complete user data scripts
- Application services to start
- ALB health checks to pass

### Step 9: Verify Deployment

#### Check ALB Target Health
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw frontend_target_group_arn)
```

#### Check EC2 Instance Status
```bash
# Frontend instances
aws ec2 describe-instances \
  --filters "Name=tag:Tier,Values=Frontend" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
  --output table

# Backend instances
aws ec2 describe-instances \
  --filters "Name=tag:Tier,Values=Backend" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table
```

#### Check RDS Status
```bash
aws rds describe-db-instances \
  --db-instance-identifier 3tier-web-app-db \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address]' \
  --output table
```

## Post-Deployment Tasks

### 1. Test Application Functionality

```bash
# Test health endpoint
curl http://$ALB_URL/health

# Test API endpoints
curl http://$ALB_URL/api/projects
curl http://$ALB_URL/api/skills
curl http://$ALB_URL/api/stats
```

### 2. Access EC2 Instances

#### Using SSH (Frontend - Public IP)
```bash
# Get frontend instance IP
FRONTEND_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Tier,Values=Frontend" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

ssh -i 3tier-app-key.pem ec2-user@$FRONTEND_IP
```

#### Using Session Manager (Recommended)
```bash
# Install Session Manager plugin
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

# Connect to instance
aws ssm start-session --target <instance-id>
```

### 3. View Application Logs

```bash
# On EC2 instance
sudo journalctl -u frontend.service -f  # Frontend logs
sudo journalctl -u backend.service -f   # Backend logs
sudo tail -f /var/log/user-data.log     # User data script logs
```

### 4. Connect to Database

```bash
# From backend EC2 instance
mysql -h <rds-endpoint> -u admin -p

# Show databases
SHOW DATABASES;
USE appdb;
SHOW TABLES;
SELECT * FROM projects;
```

## Monitoring and Maintenance

### CloudWatch Metrics

```bash
# View EC2 CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Set Up CloudWatch Alarms

```bash
# CPU alarm for EC2
aws cloudwatch put-metric-alarm \
  --alarm-name high-cpu-frontend \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## Troubleshooting

### Issue: Cannot access application

**Symptoms**: ALB URL returns timeout or connection refused

**Solutions**:
1. Check security group rules
   ```bash
   aws ec2 describe-security-groups --group-ids <alb-sg-id>
   ```

2. Verify target health
   ```bash
   aws elbv2 describe-target-health --target-group-arn <tg-arn>
   ```

3. Check EC2 instance status
   ```bash
   aws ec2 describe-instance-status --instance-ids <instance-id>
   ```

4. Review user data logs
   ```bash
   ssh -i 3tier-app-key.pem ec2-user@<instance-ip>
   sudo cat /var/log/user-data.log
   ```

### Issue: Database connection failed

**Symptoms**: Backend returns 503 errors

**Solutions**:
1. Verify RDS is available
   ```bash
   aws rds describe-db-instances --db-instance-identifier 3tier-web-app-db
   ```

2. Check security group allows backend access
   ```bash
   aws ec2 describe-security-groups --group-ids <db-sg-id>
   ```

3. Test database connectivity from backend
   ```bash
   # On backend EC2
   mysql -h <rds-endpoint> -u admin -p
   ```

4. Verify environment variables
   ```bash
   sudo systemctl status backend.service
   ```

### Issue: Terraform apply fails

**Common errors**:

1. **Key pair not found**
   ```bash
   aws ec2 create-key-pair --key-name 3tier-app-key
   ```

2. **Insufficient permissions**
   - Check IAM user permissions
   - Ensure policies allow EC2, VPC, RDS operations

3. **Resource limits exceeded**
   - Check AWS service quotas
   - Request limit increases if needed

## Scaling and Optimization

### Add Auto Scaling

```hcl
# Add to ec2.tf
resource "aws_autoscaling_group" "frontend" {
  name                = "${var.project_name}-frontend-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.frontend.arn]
  health_check_type   = "ELB"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }
}
```

### Enable HTTPS

1. Request ACM certificate
2. Update ALB listener to use HTTPS
3. Add redirect from HTTP to HTTPS

### Implement Caching

- Add ElastiCache (Redis/Memcached)
- Cache database queries
- Implement session management

## Cost Optimization

### Current Monthly Costs (Approximate)
- EC2 t3.micro (4 instances): ~$30
- RDS db.t3.micro: ~$15
- ALB: ~$20
- NAT Gateway (2): ~$70
- Data transfer: ~$10
- **Total**: ~$145/month

### Optimization Tips
1. Use Reserved Instances (save 30-70%)
2. Reduce NAT Gateways to 1 (save ~$35/month)
3. Use smaller RDS instance for dev
4. Enable RDS auto-scaling storage
5. Set up CloudWatch billing alarms

## Cleanup

### Destroy All Resources

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted.

**Important**: This will permanently delete:
- All EC2 instances
- RDS database (and all data)
- VPC and networking components
- Load balancer

### Manual Cleanup (if needed)

```bash
# Delete key pair
aws ec2 delete-key-pair --key-name 3tier-app-key
rm 3tier-app-key.pem

# Verify no resources remain
aws ec2 describe-instances --filters "Name=tag:Project,Values=3-Tier-Web-App"
```

## Security Best Practices

### Production Recommendations

1. **Network Security**
   - Restrict ALB access to specific IPs
   - Use private subnets for all application tiers
   - Implement VPC Flow Logs

2. **Database Security**
   - Enable encryption at rest
   - Use AWS Secrets Manager for credentials
   - Enable automated backups
   - Implement read replicas

3. **Application Security**
   - Enable HTTPS with valid SSL certificate
   - Implement WAF rules
   - Use parameter store for configuration
   - Enable CloudTrail logging

4. **Access Control**
   - Use IAM roles exclusively
   - Implement least privilege principle
   - Enable MFA for AWS console access
   - Use Session Manager instead of SSH

## Next Steps

1. **CI/CD Pipeline**
   - Set up GitHub Actions or AWS CodePipeline
   - Automate deployments
   - Implement blue-green deployments

2. **Monitoring**
   - Configure CloudWatch dashboards
   - Set up SNS notifications
   - Implement application performance monitoring

3. **Backup and DR**
   - Configure automated RDS snapshots
   - Implement cross-region replication
   - Document disaster recovery procedures

4. **Compliance**
   - Enable AWS Config
   - Implement compliance checks
   - Regular security audits

## Support and Resources

- [AWS Documentation](https://docs.aws.amazon.com/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

## License

MIT License - See LICENSE file for details
