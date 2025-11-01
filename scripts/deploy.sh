#!/bin/bash

# 3-Tier Web Application Deployment Script
# This script automates the deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    print_info "All prerequisites met!"
}

# Check AWS credentials
check_aws_credentials() {
    print_info "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Run 'aws configure' first."
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REGION=$(aws configure get region)
    
    print_info "AWS Account ID: $ACCOUNT_ID"
    print_info "AWS Region: $REGION"
}

# Create SSH key pair if it doesn't exist
create_key_pair() {
    KEY_NAME="3tier-app-key"
    KEY_FILE="$KEY_NAME.pem"
    
    if [ -f "$KEY_FILE" ]; then
        print_warning "Key pair $KEY_FILE already exists. Skipping creation."
        return
    fi
    
    print_info "Creating SSH key pair..."
    
    aws ec2 create-key-pair \
        --key-name $KEY_NAME \
        --query 'KeyMaterial' \
        --output text > $KEY_FILE
    
    chmod 400 $KEY_FILE
    
    print_info "Key pair created: $KEY_FILE"
}

# Initialize Terraform
init_terraform() {
    print_info "Initializing Terraform..."
    
    cd terraform
    terraform init
    cd ..
    
    print_info "Terraform initialized successfully!"
}

# Validate Terraform configuration
validate_terraform() {
    print_info "Validating Terraform configuration..."
    
    cd terraform
    
    if ! terraform validate; then
        print_error "Terraform configuration is invalid!"
        cd ..
        exit 1
    fi
    
    cd ..
    
    print_info "Terraform configuration is valid!"
}

# Create terraform.tfvars if it doesn't exist
create_tfvars() {
    TFVARS_FILE="terraform/terraform.tfvars"
    
    if [ -f "$TFVARS_FILE" ]; then
        print_warning "terraform.tfvars already exists. Skipping creation."
        return
    fi
    
    print_info "Creating terraform.tfvars from example..."
    
    cp terraform/terraform.tfvars.example $TFVARS_FILE
    
    print_warning "Please edit $TFVARS_FILE and update the db_password!"
    print_warning "Press Enter to continue after updating the file..."
    read
}

# Plan Terraform deployment
plan_terraform() {
    print_info "Planning Terraform deployment..."
    
    cd terraform
    terraform plan -out=tfplan
    cd ..
    
    print_info "Terraform plan created successfully!"
}

# Apply Terraform configuration
apply_terraform() {
    print_info "Applying Terraform configuration..."
    print_warning "This will create resources in your AWS account and may incur costs."
    print_warning "Press Enter to continue or Ctrl+C to cancel..."
    read
    
    cd terraform
    terraform apply tfplan
    cd ..
    
    print_info "Infrastructure deployed successfully!"
}

# Display outputs
display_outputs() {
    print_info "Deployment completed! Here are the outputs:"
    
    cd terraform
    
    echo ""
    echo "=========================================="
    echo "Application URL:"
    terraform output alb_url
    echo "=========================================="
    echo ""
    
    echo "Other outputs:"
    terraform output
    
    cd ..
    
    print_info "Wait 2-3 minutes for the application to fully initialize."
    print_info "Then access your application using the URL above."
}

# Test deployment
test_deployment() {
    print_info "Testing deployment..."
    
    cd terraform
    ALB_URL=$(terraform output -raw alb_url)
    cd ..
    
    print_info "Waiting for application to be ready..."
    sleep 60
    
    print_info "Testing health endpoint..."
    if curl -f "$ALB_URL/health" &> /dev/null; then
        print_info "Health check passed!"
    else
        print_warning "Health check failed. The application may still be initializing."
        print_warning "Please wait a few more minutes and try accessing: $ALB_URL"
    fi
}

# Main deployment flow
main() {
    echo ""
    echo "=========================================="
    echo "3-Tier Web Application Deployment"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    check_aws_credentials
    create_key_pair
    create_tfvars
    init_terraform
    validate_terraform
    plan_terraform
    apply_terraform
    display_outputs
    test_deployment
    
    echo ""
    print_info "Deployment completed successfully!"
    echo ""
}

# Run main function
main
