# ECR Deployment - Quick Start (5 Steps)

Get your 3-tier application running on AWS with ECR in under 20 minutes!

## Prerequisites

- AWS Account
- AWS CLI configured (`aws configure`)
- Docker installed
- Terraform installed

## Step 1: Configure AWS

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and Region
```

## Step 2: Create SSH Key Pair

```bash
aws ec2 create-key-pair \
  --key-name 3tier-app-key \
  --query 'KeyMaterial' \
  --output text > 3tier-app-key.pem

chmod 400 3tier-app-key.pem
```

## Step 3: Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Important:** Change the database password!

```hcl
db_password = "YourStrongPassword123!"  # CHANGE THIS!
use_ecr_deployment = true
image_tag = "v1.0.0"
```

## Step 4: Build and Push Docker Images

```bash
cd ..
./scripts/build-and-push.sh v1.0.0
```

**What happens:**
- ✅ Checks if ECR repositories exist
- ✅ Creates them automatically if missing
- ✅ Builds frontend and backend Docker images
- ✅ Pushes images to ECR with version tag

**Time:** ~5 minutes

## Step 5: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply -var="image_tag=v1.0.0"
```

Type `yes` when prompted.

**Time:** ~10-15 minutes

## Step 6: Access Your Application

```bash
# Get the application URL
terraform output alb_url

# Or open directly
open $(terraform output -raw alb_url)
```

Wait 2-3 minutes for health checks to pass.

---

## That's It! 🎉

Your application is now running on AWS with:
- ✅ ECR repositories created
- ✅ Docker images deployed
- ✅ High availability (multi-AZ)
- ✅ Load balancer
- ✅ RDS database
- ✅ Secure networking

## Quick Commands

### View ECR Images

```bash
aws ecr list-images --repository-name 3tier-web-app-frontend
aws ecr list-images --repository-name 3tier-web-app-backend
```

### Update Application

```bash
# 1. Make code changes in app/

# 2. Build new version
./scripts/build-and-push.sh v1.1.0

# 3. Deploy update
cd terraform
terraform apply -var="image_tag=v1.1.0"
```

### Rollback

```bash
cd terraform
terraform apply -var="image_tag=v1.0.0"
```

### Check Application Health

```bash
curl $(terraform output -raw alb_url)/health
```

### View Logs

```bash
# SSH to instance
ssh -i 3tier-app-key.pem ec2-user@<instance-ip>

# View container logs
sudo docker logs -f frontend
sudo docker logs -f backend
```

### Clean Up

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This will delete all resources.

---

## Troubleshooting

### Issue: "Repository does not exist"

**Solution:** The script now auto-creates repositories. If you see this error, check AWS credentials:

```bash
aws sts get-caller-identity
```

### Issue: "Port 5000 already in use" (local testing)

**Solution:** Use Docker Compose with port 8000:

```bash
cd app
docker-compose up -d
# Access at http://localhost:8000
```

### Issue: Application not accessible

**Wait 2-3 minutes** after deployment for:
- User data scripts to complete
- Containers to start
- Health checks to pass

Check status:
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names 3tier-web-app-frontend-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
```

### Issue: Terraform init fails

**Solution:** Make sure you're in the terraform directory:

```bash
cd terraform
terraform init
```

---

## Next Steps

1. **Customize the application**
   - Edit `app/frontend/templates/index.html`
   - Update `app/backend/app.py`

2. **Set up CI/CD**
   - GitHub Actions
   - AWS CodePipeline
   - GitLab CI

3. **Add monitoring**
   - CloudWatch dashboards
   - Container Insights
   - Alarms

4. **Secure further**
   - Add HTTPS with ACM
   - Restrict ALB access
   - Use Secrets Manager

---

## Cost Estimate

**Monthly:** ~$145
- EC2: $30
- RDS: $15
- ALB: $20
- NAT Gateway: $70
- ECR: $0.25
- Data transfer: $10

**To reduce costs:**
- Use smaller instances
- Stop when not needed
- Use Reserved Instances

---

## Documentation

- **Full ECR Guide:** [ECR_DEPLOYMENT.md](ECR_DEPLOYMENT.md)
- **Comparison:** [DEPLOYMENT_COMPARISON.md](DEPLOYMENT_COMPARISON.md)
- **Local Development:** [DOCKER_GUIDE.md](DOCKER_GUIDE.md)
- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md)

---

**Happy Deploying! 🚀**
