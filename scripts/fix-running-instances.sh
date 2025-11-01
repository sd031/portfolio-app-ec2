#!/bin/bash

# Fix running instances with corrected container startup
# This script manually starts containers on existing instances

set -e

export AWS_PROFILE=personal_new
AWS_REGION="us-west-2"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo ""
echo "=========================================="
echo "Fix Running Instances"
echo "=========================================="
echo ""

# Check for SSH key
if [ ! -f "3tier-app-key.pem" ]; then
    print_error "SSH key '3tier-app-key.pem' not found"
    echo "Please ensure the key is in the current directory"
    exit 1
fi

chmod 400 3tier-app-key.pem

# Get frontend instances
print_step "Getting frontend instances..."
FRONTEND_INSTANCES=$(aws ec2 describe-instances --region $AWS_REGION \
    --filters "Name=tag:Name,Values=project-3tier-web-app-frontend-*" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' \
    --output text)

if [ -z "$FRONTEND_INSTANCES" ]; then
    print_error "No running frontend instances found"
    exit 1
fi

print_info "Found frontend instances:"
echo "$FRONTEND_INSTANCES"
echo ""

# Get ECR details from Terraform
cd terraform
FRONTEND_REPO=$(terraform output -raw ecr_frontend_repository_url 2>/dev/null)
IMAGE_TAG=$(terraform output -raw image_tag 2>/dev/null || echo "v1.0.0")
cd ..

print_info "Frontend Image: $FRONTEND_REPO:$IMAGE_TAG"
echo ""

# Fix each frontend instance
echo "$FRONTEND_INSTANCES" | while read INSTANCE_ID PUBLIC_IP; do
    print_step "Fixing instance $INSTANCE_ID ($PUBLIC_IP)..."
    
    # Create fix script
    cat > /tmp/fix-frontend.sh << EOF
#!/bin/bash
set -e

echo "Getting AWS region..."
TOKEN=\$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
REGION=\$(curl -H "X-aws-ec2-metadata-token: \$TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)

if [ -z "\$REGION" ]; then
    REGION=\$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
fi

echo "Region: \$REGION"

AWS_ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text --region \$REGION)
ECR_REGISTRY="\$AWS_ACCOUNT_ID.dkr.ecr.\$REGION.amazonaws.com"

echo "Logging into ECR..."
aws ecr get-login-password --region "\$REGION" | sudo docker login --username AWS --password-stdin "\$ECR_REGISTRY"

echo "Pulling image..."
sudo docker pull $FRONTEND_REPO:$IMAGE_TAG

echo "Stopping old container if exists..."
sudo docker stop frontend 2>/dev/null || true
sudo docker rm frontend 2>/dev/null || true

echo "Starting frontend container..."
sudo docker run -d --name frontend --restart unless-stopped -p 5000:5000 $FRONTEND_REPO:$IMAGE_TAG

echo "Checking container status..."
sudo docker ps | grep frontend

echo "Testing health endpoint..."
sleep 5
curl -f http://localhost:5000/health || echo "Health check failed"
EOF

    # Copy and execute fix script
    scp -i 3tier-app-key.pem -o StrictHostKeyChecking=no /tmp/fix-frontend.sh ec2-user@$PUBLIC_IP:/tmp/
    ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "chmod +x /tmp/fix-frontend.sh && sudo /tmp/fix-frontend.sh"
    
    if [ $? -eq 0 ]; then
        print_info "✓ Instance $INSTANCE_ID fixed successfully"
    else
        print_error "✗ Failed to fix instance $INSTANCE_ID"
    fi
    echo ""
done

# Wait for health checks
print_step "Waiting for health checks to pass (this may take 2-3 minutes)..."
sleep 30

# Check target health
print_step "Checking target health..."
TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
    --query 'TargetGroups[?contains(TargetGroupName, `project-3tier-web-app-fe`)].TargetGroupArn' \
    --output text)

aws elbv2 describe-target-health --region $AWS_REGION \
    --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
    --output table

echo ""
print_info "Fix complete!"
echo ""
print_warning "If targets are still unhealthy, wait 2-3 minutes for health checks to pass"
echo ""
print_info "Test the application:"
echo "  curl http://project-3tier-web-app-alb-220221624.us-west-2.elb.amazonaws.com"
echo ""
