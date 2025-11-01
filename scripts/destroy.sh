#!/bin/bash

# 3-Tier Web Application Destroy Script
# This script safely destroys all AWS resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Confirm destruction
confirm_destroy() {
    echo ""
    echo "=========================================="
    print_warning "WARNING: This will destroy ALL resources!"
    echo "=========================================="
    echo ""
    print_warning "This action will permanently delete:"
    echo "  - All EC2 instances"
    echo "  - RDS database (and all data)"
    echo "  - Load Balancer"
    echo "  - VPC and networking components"
    echo "  - All associated resources"
    echo ""
    print_warning "This action CANNOT be undone!"
    echo ""
    read -p "Type 'yes' to confirm destruction: " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        print_info "Destruction cancelled."
        exit 0
    fi
}

# Destroy infrastructure
destroy_infrastructure() {
    print_info "Destroying infrastructure..."
    
    cd terraform
    
    if ! terraform destroy -auto-approve; then
        print_error "Terraform destroy failed!"
        print_info "You may need to manually clean up some resources."
        cd ..
        exit 1
    fi
    
    cd ..
    
    print_info "Infrastructure destroyed successfully!"
}

# Delete key pair
delete_key_pair() {
    KEY_NAME="3tier-app-key"
    KEY_FILE="$KEY_NAME.pem"
    
    print_info "Deleting SSH key pair..."
    
    if aws ec2 describe-key-pairs --key-names $KEY_NAME &> /dev/null; then
        aws ec2 delete-key-pair --key-name $KEY_NAME
        print_info "Key pair deleted from AWS"
    fi
    
    if [ -f "$KEY_FILE" ]; then
        rm -f $KEY_FILE
        print_info "Local key file deleted"
    fi
}

# Clean up Terraform files
cleanup_terraform_files() {
    print_info "Cleaning up Terraform files..."
    
    cd terraform
    rm -f tfplan
    rm -f terraform.tfstate.backup
    cd ..
    
    print_info "Terraform files cleaned up"
}

# Main destroy flow
main() {
    echo ""
    echo "=========================================="
    echo "3-Tier Web Application Destruction"
    echo "=========================================="
    echo ""
    
    confirm_destroy
    destroy_infrastructure
    delete_key_pair
    cleanup_terraform_files
    
    echo ""
    print_info "All resources have been destroyed!"
    print_info "Your AWS account has been cleaned up."
    echo ""
}

# Run main function
main
