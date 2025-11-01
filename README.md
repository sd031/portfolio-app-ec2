# 3-Tier Web Application on AWS

A production-ready 3-tier web application deployed on AWS using Terraform.

## Architecture Overview

### Tiers
1. **Presentation Tier (Frontend)**: Flask-based personal portfolio hosted on EC2 instances behind an Application Load Balancer
2. **Application Tier (Backend)**: Flask API backend on EC2 instances in private subnets
3. **Data Tier (Database)**: RDS MySQL database in private subnets

### AWS Services Used
- **VPC**: Custom VPC with public and private subnets across 2 availability zones
- **EC2**: Auto-scaling instances for frontend and backend
- **ECR**: Elastic Container Registry for Docker images
- **Application Load Balancer**: Distributes traffic to frontend instances
- **RDS MySQL**: Managed database service
- **Security Groups**: Network-level security
- **IAM Roles**: Secure access management
- **NAT Gateway**: Outbound internet access for private subnets

### Deployment Approaches

This project supports **two deployment methods**:

1. **ECR-Based (Recommended)**: Modern approach using Docker containers and ECR
   - Faster deployments
   - Easy version control and rollbacks
   - CI/CD ready
   - See [ECR_DEPLOYMENT.md](ECR_DEPLOYMENT.md)

2. **Traditional**: Direct code deployment via user data scripts
   - Simpler for learning
   - No Docker required
   - See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- Terraform >= 1.0
- SSH key pair for EC2 access

## Project Structure

```
3-tier-web-app/
├── terraform/
│   ├── main.tf              # Main Terraform configuration
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values
│   ├── vpc.tf              # VPC and networking
│   ├── security_groups.tf  # Security group rules
│   ├── ec2.tf              # EC2 instances and IAM roles
│   ├── ecr.tf              # ECR repositories
│   ├── alb.tf              # Application Load Balancer
│   ├── rds.tf              # RDS MySQL database
│   └── terraform.tfvars.example  # Example variables file
├── app/
│   ├── docker-compose.yml  # Local development
│   ├── frontend/           # Frontend Flask application
│   │   ├── Dockerfile
│   │   ├── app.py
│   │   └── templates/
│   └── backend/            # Backend Flask API
│       ├── Dockerfile
│       ├── app.py
│       └── requirements.txt
├── scripts/
│   ├── build-and-push.sh   # Build and push to ECR
│   ├── deploy.sh           # Automated deployment
│   ├── user_data_frontend_v2.sh  # ECR-based (recommended)
│   ├── user_data_backend_v2.sh   # ECR-based (recommended)
│   ├── user_data_frontend.sh     # Traditional
│   └── user_data_backend.sh      # Traditional
├── ECR_DEPLOYMENT.md       # ECR deployment guide
├── DEPLOYMENT_GUIDE.md     # Traditional deployment guide
├── DOCKER_GUIDE.md         # Local Docker development
└── README.md
```

## Setup Instructions

### 1. Clone and Initialize

```bash
cd 3-tier-web-app
git init
```

### 2. Configure AWS Credentials

```bash
aws configure
```

### 3. Create SSH Key Pair

```bash
aws ec2 create-key-pair --key-name 3tier-app-key --query 'KeyMaterial' --output text > 3tier-app-key.pem
chmod 400 3tier-app-key.pem
```

### 4. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 5. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 6. Access the Application

After deployment, Terraform will output the Load Balancer DNS name:

```bash
terraform output alb_dns_name
```

Access your application at: `http://<alb_dns_name>`

## Security Features

### Network Security
- **Public Subnets**: Only ALB and NAT Gateway
- **Private Subnets**: Backend EC2 and RDS instances
- **Security Groups**: 
  - ALB: Allows HTTP/HTTPS from internet
  - Frontend EC2: Allows traffic only from ALB
  - Backend EC2: Allows traffic only from Frontend
  - RDS: Allows MySQL traffic only from Backend

### IAM Security
- EC2 instances use IAM roles (no hardcoded credentials)
- Principle of least privilege applied
- RDS credentials stored securely

## Application Features

### Frontend (Personal Portfolio)
- Responsive design
- About, Projects, Skills, Contact sections
- Communicates with backend API

### Backend API
- RESTful API endpoints
- Database connectivity
- Health check endpoint

## Monitoring and Maintenance

### View Logs
```bash
# SSH to instances (via bastion or Session Manager)
ssh -i 3tier-app-key.pem ec2-user@<instance-ip>
sudo tail -f /var/log/app.log
```

### Database Access
```bash
# Connect to RDS from backend instance
mysql -h <rds-endpoint> -u admin -p
```

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

## Cost Estimation

- EC2 instances (t3.micro): ~$15/month
- RDS (db.t3.micro): ~$15/month
- ALB: ~$20/month
- NAT Gateway: ~$35/month
- **Total**: ~$85/month (approximate)

## Troubleshooting

### Issue: Cannot connect to application
- Check security group rules
- Verify EC2 instances are running
- Check ALB target health

### Issue: Database connection failed
- Verify RDS security group allows backend access
- Check database credentials
- Ensure RDS instance is available

## Future Enhancements

- [ ] Add Auto Scaling policies
- [ ] Implement CloudWatch monitoring and alarms
- [ ] Add SSL/TLS certificate (ACM)
- [ ] Implement CI/CD pipeline
- [ ] Add ElastiCache for session management
- [ ] Implement backup and disaster recovery

## License

MIT License
# portfolio-app-ec2
