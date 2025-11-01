# Terraform Setup Guide

## Quick Start

### 1. Create terraform.tfvars File

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars

```bash
nano terraform.tfvars
# or
vim terraform.tfvars
# or
code terraform.tfvars
```

**Required Changes:**

```hcl
# IMPORTANT: Change these values!
aws_region   = "us-west-2"        # Your AWS region
key_name     = "3tier-app-key"    # Your SSH key pair name
db_password  = "YourStrongPassword123!"  # Strong database password

# ECR Deployment (recommended)
use_ecr_deployment = true
image_tag          = "v1.0.0"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Deploy

```bash
# With tfvars file (automatic)
terraform apply

# Or override specific variables
terraform apply -var='image_tag=v1.1.0'
```

## terraform.tfvars File

### What is it?

`terraform.tfvars` is a special file that Terraform automatically loads to set variable values. This eliminates the need to pass `-var` flags or enter values interactively.

### Security

✅ **Automatically gitignored** - Your passwords and secrets won't be committed  
✅ **Local only** - Each developer has their own copy  
✅ **Not shared** - Never commit this file to version control  

### Example terraform.tfvars

```hcl
# AWS Configuration
aws_region   = "us-west-2"
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
db_password       = "MySecurePassword123!"  # CHANGE THIS!

# Security Configuration
allowed_cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production

# ECR Deployment Configuration
use_ecr_deployment = true
image_tag          = "v1.0.0"
```

## Variable Priority

Terraform loads variables in this order (later overrides earlier):

1. **Environment variables** (`TF_VAR_name`)
2. **terraform.tfvars** (auto-loaded)
3. **terraform.tfvars.json** (auto-loaded)
4. ***.auto.tfvars** (auto-loaded)
5. **-var-file** flag
6. **-var** flag (highest priority)

### Examples

```bash
# Use terraform.tfvars (automatic)
terraform apply

# Override specific variable
terraform apply -var='image_tag=v2.0.0'

# Use different tfvars file
terraform apply -var-file='production.tfvars'

# Use environment variable
export TF_VAR_db_password="SecurePassword"
terraform apply
```

## Multiple Environments

### Development

```bash
# terraform/dev.tfvars
aws_region   = "us-west-2"
environment  = "dev"
instance_type = "t3.micro"
db_password  = "DevPassword123!"
```

```bash
terraform apply -var-file='dev.tfvars'
```

### Production

```bash
# terraform/prod.tfvars
aws_region   = "us-east-1"
environment  = "prod"
instance_type = "t3.small"
db_password  = "ProdPassword123!"
```

```bash
terraform apply -var-file='prod.tfvars'
```

## Common Variables

### AWS Configuration

```hcl
aws_region   = "us-west-2"  # AWS region
environment  = "dev"        # Environment name
project_name = "3tier-web-app"  # Project identifier
```

### Network Configuration

```hcl
vpc_cidr                = "10.0.0.0/16"
public_subnet_cidrs     = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs    = ["10.0.11.0/24", "10.0.12.0/24"]
database_subnet_cidrs   = ["10.0.21.0/24", "10.0.22.0/24"]
```

### EC2 Configuration

```hcl
instance_type = "t3.micro"      # EC2 instance size
key_name      = "3tier-app-key" # SSH key pair name
```

### Database Configuration

```hcl
db_instance_class = "db.t3.micro"  # RDS instance size
db_name           = "appdb"        # Database name
db_username       = "admin"        # Database username
db_password       = "SecurePass!"  # Database password (CHANGE THIS!)
```

### Security Configuration

```hcl
# Allow access from anywhere (development)
allowed_cidr_blocks = ["0.0.0.0/0"]

# Restrict to your IP (production)
allowed_cidr_blocks = ["203.0.113.0/32"]

# Multiple IPs
allowed_cidr_blocks = ["203.0.113.0/32", "198.51.100.0/24"]
```

### ECR Configuration

```hcl
use_ecr_deployment = true    # Use ECR-based deployment
image_tag          = "v1.0.0"  # Docker image tag
```

## Sensitive Variables

### Best Practices

1. **Never commit terraform.tfvars** - Already gitignored
2. **Use strong passwords** - Minimum 12 characters
3. **Rotate regularly** - Change passwords periodically
4. **Use AWS Secrets Manager** - For production (advanced)

### Using Environment Variables

```bash
# Set database password via environment variable
export TF_VAR_db_password="MySecurePassword123!"

# Run terraform without tfvars file
terraform apply
```

### Using AWS Secrets Manager (Advanced)

```hcl
# In variables.tf
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}

locals {
  db_password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}
```

## Validation

### Check Variables

```bash
# Show all variables
terraform console
> var.aws_region
> var.db_password
> exit

# Validate configuration
terraform validate

# Show plan without applying
terraform plan
```

### Verify Values

```bash
# Check what Terraform will use
terraform plan | grep -A 5 "aws_region"
terraform plan | grep -A 5 "instance_type"
```

## Troubleshooting

### Error: "No value for required variable"

**Problem:**
```
Error: No value for required variable
  on variables.tf line 74:
  74: variable "db_password" {
```

**Solution:**
```bash
# Create terraform.tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit and add db_password
nano terraform.tfvars
```

### Error: "terraform.tfvars not found"

**Problem:** File doesn't exist

**Solution:**
```bash
# Create from example
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### Error: "Invalid value for variable"

**Problem:** Variable format is incorrect

**Solution:**
```hcl
# Strings need quotes
aws_region = "us-west-2"  # ✅ Correct
aws_region = us-west-2    # ❌ Wrong

# Lists need brackets
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]  # ✅ Correct
public_subnet_cidrs = "10.0.1.0/24"                   # ❌ Wrong

# Booleans don't need quotes
use_ecr_deployment = true   # ✅ Correct
use_ecr_deployment = "true" # ❌ Wrong (string, not boolean)
```

## Complete Workflow

### First-Time Setup

```bash
# 1. Navigate to terraform directory
cd terraform

# 2. Create tfvars file
cp terraform.tfvars.example terraform.tfvars

# 3. Edit with your values
nano terraform.tfvars

# 4. Initialize Terraform
terraform init

# 5. Review plan
terraform plan

# 6. Apply
terraform apply
```

### Subsequent Deployments

```bash
cd terraform

# With default values from terraform.tfvars
terraform apply

# Override specific variable
terraform apply -var='image_tag=v1.1.0'

# Use different environment
terraform apply -var-file='production.tfvars'
```

## Security Checklist

- [ ] `terraform.tfvars` is gitignored
- [ ] Strong database password set (12+ characters)
- [ ] SSH key pair created in AWS
- [ ] `allowed_cidr_blocks` restricted (not 0.0.0.0/0 in production)
- [ ] AWS credentials configured (`aws configure`)
- [ ] Never commit secrets to git

## Quick Reference

| Task | Command |
|------|---------|
| **Create tfvars** | `cp terraform.tfvars.example terraform.tfvars` |
| **Edit tfvars** | `nano terraform.tfvars` |
| **Initialize** | `terraform init` |
| **Plan** | `terraform plan` |
| **Apply** | `terraform apply` |
| **Override variable** | `terraform apply -var='key=value'` |
| **Different file** | `terraform apply -var-file='prod.tfvars'` |
| **Destroy** | `terraform destroy` |

## Summary

✅ **Use terraform.tfvars** - Automatic variable loading  
✅ **Never commit it** - Already gitignored  
✅ **Change defaults** - Especially passwords!  
✅ **Override when needed** - Use `-var` flag  
✅ **Multiple environments** - Use different tfvars files  

---

**Ready to deploy!** 🚀
