#!/bin/bash

# Diagnose 502 Bad Gateway Error
# This script checks the health of EC2 instances and containers

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Set AWS profile
export AWS_PROFILE=personal_new
AWS_REGION="us-west-2"

echo ""
echo "=========================================="
echo "502 Bad Gateway Diagnostic Tool"
echo "=========================================="
echo ""

# Get target group ARN
print_step "Getting target group information..."
TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
    --query 'TargetGroups[?contains(TargetGroupName, `project-3tier-web-app-fe`)].TargetGroupArn' \
    --output text)

if [ -z "$TG_ARN" ]; then
    print_error "Target group not found"
    exit 1
fi

print_info "Target Group: $TG_ARN"

# Get target health
print_step "Checking target health..."
aws elbv2 describe-target-health --region $AWS_REGION \
    --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
    --output table

# Get frontend instances
print_step "Getting frontend instance details..."
INSTANCES=$(aws ec2 describe-instances --region $AWS_REGION \
    --filters "Name=tag:Name,Values=project-3tier-web-app-frontend-*" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,PrivateIpAddress]' \
    --output text)

if [ -z "$INSTANCES" ]; then
    print_error "No running frontend instances found"
    exit 1
fi

echo ""
print_info "Frontend Instances:"
echo "$INSTANCES" | while read INSTANCE_ID PUBLIC_IP PRIVATE_IP; do
    echo "  - Instance: $INSTANCE_ID"
    echo "    Public IP: $PUBLIC_IP"
    echo "    Private IP: $PRIVATE_IP"
done

echo ""
print_step "Checking what's wrong with the instances..."
echo ""

# Check first instance in detail
FIRST_INSTANCE=$(echo "$INSTANCES" | head -1 | awk '{print $1}')
FIRST_PUBLIC_IP=$(echo "$INSTANCES" | head -1 | awk '{print $2}')

print_info "Checking instance: $FIRST_INSTANCE ($FIRST_PUBLIC_IP)"
echo ""

# Check if we can reach the instance (requires SSH key)
if [ -f "3tier-app-key.pem" ]; then
    print_step "Attempting to connect and check status..."
    
    # Check if Docker is running
    print_info "Checking Docker status..."
    ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        ec2-user@$FIRST_PUBLIC_IP "sudo systemctl status docker" 2>/dev/null || \
        print_warning "Could not check Docker status (SSH may not be configured)"
    
    echo ""
    
    # Check if container is running
    print_info "Checking Docker containers..."
    ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        ec2-user@$FIRST_PUBLIC_IP "sudo docker ps -a" 2>/dev/null || \
        print_warning "Could not check containers (SSH may not be configured)"
    
    echo ""
    
    # Check container logs
    print_info "Checking container logs (last 20 lines)..."
    ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        ec2-user@$FIRST_PUBLIC_IP "sudo docker logs --tail 20 frontend 2>&1" 2>/dev/null || \
        print_warning "Could not check container logs"
    
    echo ""
    
    # Check if port 5000 is listening
    print_info "Checking if port 5000 is listening..."
    ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        ec2-user@$FIRST_PUBLIC_IP "sudo netstat -tlnp | grep 5000 || sudo ss -tlnp | grep 5000" 2>/dev/null || \
        print_warning "Could not check port status"
    
    echo ""
    
    # Check user data execution
    print_info "Checking user data logs..."
    ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        ec2-user@$FIRST_PUBLIC_IP "sudo tail -50 /var/log/cloud-init-output.log" 2>/dev/null || \
        print_warning "Could not check user data logs"
    
else
    print_warning "SSH key '3tier-app-key.pem' not found in current directory"
    print_warning "Cannot perform detailed instance checks"
    echo ""
    print_info "To check manually, SSH to instance:"
    echo "  ssh -i 3tier-app-key.pem ec2-user@$FIRST_PUBLIC_IP"
    echo ""
    print_info "Then run these commands:"
    echo "  sudo docker ps -a"
    echo "  sudo docker logs frontend"
    echo "  sudo systemctl status frontend-container"
    echo "  sudo journalctl -u frontend-container -n 50"
    echo "  curl http://localhost:5000/health"
fi

echo ""
print_step "Common issues and solutions:"
echo ""
echo "1. Container not running:"
echo "   - Check: sudo docker ps -a"
echo "   - Fix: sudo systemctl restart frontend-container"
echo ""
echo "2. Port mismatch:"
echo "   - Target group expects port 5000"
echo "   - Check container is listening on 5000"
echo ""
echo "3. Health check path:"
echo "   - ALB checks /health endpoint"
echo "   - Ensure app responds to /health"
echo ""
echo "4. Security group:"
echo "   - ALB must be able to reach instances on port 5000"
echo "   - Check security group rules"
echo ""
echo "5. Container failed to start:"
echo "   - Check logs: sudo docker logs frontend"
echo "   - Check image was pulled: sudo docker images"
echo ""

echo "=========================================="
print_info "Diagnostic complete"
echo "=========================================="
echo ""
