# Quick Start Guide

Get your 3-tier web application running on AWS in under 15 minutes!

## Prerequisites

- AWS Account
- AWS CLI installed and configured
- Terraform installed (>= 1.0)

## Quick Deploy (5 Steps)

### 1. Configure AWS Credentials

```bash
aws configure
```

### 2. Create SSH Key Pair

```bash
aws ec2 create-key-pair \
  --key-name 3tier-app-key \
  --query 'KeyMaterial' \
  --output text > 3tier-app-key.pem

chmod 400 3tier-app-key.pem
```

### 3. Configure Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and **change the database password**:
```hcl
db_password = "YourStrongPassword123!"  # CHANGE THIS!
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Deploy
terraform apply
```

Type `yes` when prompted.

**Wait time**: ~10-15 minutes

### 5. Access Your Application

```bash
# Get the application URL
terraform output alb_url

# Or open in browser
open $(terraform output -raw alb_url)
```

Wait 2-3 minutes for the application to fully initialize.

## Using the Automated Script

Alternatively, use the deployment script:

```bash
# Make script executable
chmod +x scripts/deploy.sh

# Run deployment
./scripts/deploy.sh
```

The script will:
- Check prerequisites
- Create SSH key pair
- Initialize Terraform
- Deploy infrastructure
- Display outputs

## What Gets Created

- **VPC** with 6 subnets across 2 AZs
- **2 Frontend EC2** instances (public subnets)
- **2 Backend EC2** instances (private subnets)
- **Application Load Balancer** (internet-facing)
- **RDS MySQL** database (private subnet)
- **NAT Gateways** for private subnet internet access
- **Security Groups** for network isolation
- **IAM Roles** for EC2 instances

## Verify Deployment

### Check Application Health

```bash
# Get ALB URL
ALB_URL=$(terraform output -raw alb_url)

# Test health endpoint
curl $ALB_URL/health

# Test API endpoints
curl $ALB_URL/api/projects
curl $ALB_URL/api/skills
curl $ALB_URL/api/stats
```

### Check AWS Resources

```bash
# List EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=3-Tier-Web-App" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress]' \
  --output table

# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier 3tier-web-app-db \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address]' \
  --output table

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names 3tier-web-app-frontend-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
```

## Access EC2 Instances

### SSH to Frontend Instance

```bash
# Get frontend instance IP
FRONTEND_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Tier,Values=Frontend" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# SSH to instance
ssh -i 3tier-app-key.pem ec2-user@$FRONTEND_IP
```

### View Application Logs

```bash
# On EC2 instance
sudo journalctl -u frontend.service -f  # Frontend logs
sudo journalctl -u backend.service -f   # Backend logs
sudo tail -f /var/log/user-data.log     # Setup logs
```

## Troubleshooting

### Application not accessible

**Wait 2-3 minutes** after deployment for:
- User data scripts to complete
- Applications to start
- Health checks to pass

### Check target health

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

Targets should show `healthy` status.

### Check application logs

```bash
# SSH to instance
ssh -i 3tier-app-key.pem ec2-user@<instance-ip>

# Check service status
sudo systemctl status frontend.service
sudo systemctl status backend.service

# View logs
sudo journalctl -u frontend.service -n 50
```

### Database connection issues

```bash
# On backend instance
mysql -h <rds-endpoint> -u admin -p

# If connection fails, check:
# 1. RDS security group allows backend SG
# 2. RDS is in 'available' state
# 3. Credentials are correct
```

## Clean Up

### Destroy All Resources

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted.

### Or Use the Destroy Script

```bash
./scripts/destroy.sh
```

This will:
- Destroy all AWS resources
- Delete SSH key pair
- Clean up local files

**Warning**: This permanently deletes all data!

## Cost Estimate

**Monthly cost**: ~$145
- EC2 instances: $30
- RDS: $15
- ALB: $20
- NAT Gateways: $70
- Data transfer: $10

**To reduce costs**:
- Use smaller instance types
- Reduce to 1 NAT Gateway
- Use Reserved Instances
- Stop instances when not needed

## Next Steps

1. **Customize the portfolio**
   - Edit `app/frontend/templates/index.html`
   - Update personal information
   - Add your projects

2. **Secure the application**
   - Restrict ALB access to your IP
   - Enable HTTPS with ACM certificate
   - Use AWS Secrets Manager for DB credentials

3. **Add monitoring**
   - Set up CloudWatch dashboards
   - Configure alarms
   - Enable detailed monitoring

4. **Implement CI/CD**
   - Set up GitHub Actions
   - Automate deployments
   - Add automated testing

## Documentation

- **README.md**: Project overview
- **DEPLOYMENT_GUIDE.md**: Detailed deployment instructions
- **ARCHITECTURE.md**: Architecture documentation
- **Terraform files**: Infrastructure as code

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Check AWS service health dashboard
4. Review Terraform state

## Security Best Practices

1. **Change default passwords** in terraform.tfvars
2. **Restrict SSH access** to your IP only
3. **Enable MFA** on your AWS account
4. **Use IAM roles** instead of access keys
5. **Enable CloudTrail** for audit logging
6. **Regular security updates** on EC2 instances

## Architecture Highlights

✅ **High Availability**: Multi-AZ deployment  
✅ **Security**: Private subnets, security groups, IAM roles  
✅ **Scalability**: Load balancer, auto-scaling ready  
✅ **Monitoring**: CloudWatch metrics and alarms  
✅ **Infrastructure as Code**: Fully automated with Terraform  

---

**Happy Deploying! 🚀**
