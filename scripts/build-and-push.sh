#!/bin/bash

# Build and Push Docker Images to ECR
# This script builds the frontend and backend Docker images and pushes them to ECR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if we're in the right directory
if [ ! -d "app" ] || [ ! -d "terraform" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker Desktop."
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running. Please start Docker Desktop."
    exit 1
fi

# Verify Docker supports multi-platform builds
print_info "Verifying Docker buildx support..."
if ! docker buildx version &> /dev/null; then
    print_warning "Docker buildx not available. Using standard build (may have platform issues)."
    print_warning "For best results, update to Docker Desktop with buildx support."
    USE_BUILDX=false
else
    print_info "Docker buildx available - will build for linux/amd64 platform"
    USE_BUILDX=true
fi

# Get AWS account ID and region
print_step "Getting AWS account information..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)

if [ -z "$AWS_ACCOUNT_ID" ] || [ -z "$AWS_REGION" ]; then
    print_error "Failed to get AWS account information. Please configure AWS CLI."
    exit 1
fi

print_info "AWS Account ID: $AWS_ACCOUNT_ID"
print_info "AWS Region: $AWS_REGION"

# Define repository names
PROJECT_NAME="project-3tier-web-app"
FRONTEND_REPO_NAME="${PROJECT_NAME}-frontend"
BACKEND_REPO_NAME="${PROJECT_NAME}-backend"

# Function to create ECR repository if it doesn't exist
create_ecr_repo_if_not_exists() {
    local repo_name=$1
    local repo_url="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$repo_name"
    
    print_step "Checking if ECR repository '$repo_name' exists..." >&2
    
    if aws ecr describe-repositories --repository-names $repo_name --region $AWS_REGION &>/dev/null; then
        print_info "Repository '$repo_name' already exists" >&2
    else
        print_warning "Repository '$repo_name' not found. Creating..." >&2
        
        aws ecr create-repository \
            --repository-name $repo_name \
            --region $AWS_REGION \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 \
            --tags Key=Project,Value=$PROJECT_NAME Key=ManagedBy,Value=Script &>/dev/null
        
        if [ $? -eq 0 ]; then
            print_info "Repository '$repo_name' created successfully" >&2
            
            # Add lifecycle policy to keep last 5 images
            aws ecr put-lifecycle-policy \
                --repository-name $repo_name \
                --region $AWS_REGION \
                --lifecycle-policy-text '{
                    "rules": [{
                        "rulePriority": 1,
                        "description": "Keep last 5 images",
                        "selection": {
                            "tagStatus": "tagged",
                            "tagPrefixList": ["v"],
                            "countType": "imageCountMoreThan",
                            "countNumber": 5
                        },
                        "action": {
                            "type": "expire"
                        }
                    }]
                }' &>/dev/null
            
            print_info "Lifecycle policy added to '$repo_name'" >&2
        else
            print_error "Failed to create repository '$repo_name'" >&2
            exit 1
        fi
    fi
    
    echo $repo_url
}

# Create or get ECR repositories
FRONTEND_REPO=$(create_ecr_repo_if_not_exists $FRONTEND_REPO_NAME)
BACKEND_REPO=$(create_ecr_repo_if_not_exists $BACKEND_REPO_NAME)

print_info "Frontend ECR: $FRONTEND_REPO"
print_info "Backend ECR: $BACKEND_REPO"

# Get image tag (default to latest, or use argument)
IMAGE_TAG="${1:-latest}"
print_info "Image tag: $IMAGE_TAG"

# Login to ECR
print_step "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

if [ $? -ne 0 ]; then
    print_error "Failed to login to ECR"
    exit 1
fi

print_info "Successfully logged into ECR"

# Build and push frontend image
print_step "Building frontend Docker image for linux/amd64..."
cd app/frontend

if [ "$USE_BUILDX" = true ]; then
    docker buildx build --platform linux/amd64 --load -t $FRONTEND_REPO:$IMAGE_TAG -t $FRONTEND_REPO:latest .
else
    docker build -t $FRONTEND_REPO:$IMAGE_TAG -t $FRONTEND_REPO:latest .
fi

if [ $? -ne 0 ]; then
    print_error "Failed to build frontend image"
    exit 1
fi

print_info "Frontend image built successfully"

print_step "Pushing frontend image to ECR..."
docker push $FRONTEND_REPO:$IMAGE_TAG
docker push $FRONTEND_REPO:latest

if [ $? -ne 0 ]; then
    print_error "Failed to push frontend image"
    exit 1
fi

print_info "Frontend image pushed successfully"

cd ../..

# Build and push backend image
print_step "Building backend Docker image for linux/amd64..."
cd app/backend

if [ "$USE_BUILDX" = true ]; then
    docker buildx build --platform linux/amd64 --load -t $BACKEND_REPO:$IMAGE_TAG -t $BACKEND_REPO:latest .
else
    docker build -t $BACKEND_REPO:$IMAGE_TAG -t $BACKEND_REPO:latest .
fi

if [ $? -ne 0 ]; then
    print_error "Failed to build backend image"
    exit 1
fi

print_info "Backend image built successfully"

print_step "Pushing backend image to ECR..."
docker push $BACKEND_REPO:$IMAGE_TAG
docker push $BACKEND_REPO:latest

if [ $? -ne 0 ]; then
    print_error "Failed to push backend image"
    exit 1
fi

print_info "Backend image pushed successfully"

cd ../..

# Summary
echo ""
echo "=========================================="
print_info "Build and Push Completed Successfully!"
echo "=========================================="
echo ""
print_info "Frontend Image: $FRONTEND_REPO:$IMAGE_TAG"
print_info "Backend Image: $BACKEND_REPO:$IMAGE_TAG"
if [ "$USE_BUILDX" = true ]; then
    print_info "Platform: linux/amd64 (compatible with AWS EC2)"
else
    print_warning "Platform: native (may not be compatible with AWS EC2 x86_64 instances)"
    print_warning "Consider updating Docker to use buildx for cross-platform builds"
fi
echo ""
print_warning "Next steps:"
echo "  1. Initialize Terraform: cd terraform && terraform init"
echo "  2. Deploy infrastructure: terraform apply -var='image_tag=$IMAGE_TAG'"
echo "  3. Access application: terraform output alb_url"
echo ""
