#!/bin/bash

# Quick fix for running instances
# Manually start containers on instances where user data failed

set -e

export AWS_PROFILE=personal_new
AWS_REGION="us-west-2"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Get instance IPs
print_step "Getting frontend instances..."
FRONTEND_IPS=$(aws ec2 describe-instances --region $AWS_REGION \
    --filters "Name=tag:Name,Values=project-3tier-web-app-frontend-*" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text)

BACKEND_IP=$(aws ec2 describe-instances --region $AWS_REGION \
    --filters "Name=tag:Name,Values=project-3tier-web-app-backend-1" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

print_info "Frontend IPs: $FRONTEND_IPS"
print_info "Backend IP: $BACKEND_IP"

# Fix each frontend instance
for IP in $FRONTEND_IPS; do
    print_step "Fixing frontend instance at $IP..."
    
    ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no ec2-user@$IP << 'ENDSSH'
# Get region and login to ECR
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)

aws ecr get-login-password --region "$REGION" | sudo docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# Stop and remove old container
sudo docker stop frontend 2>/dev/null || true
sudo docker rm frontend 2>/dev/null || true

# Pull and run
sudo docker pull 211125312702.dkr.ecr.us-west-2.amazonaws.com/project-3tier-web-app-frontend:v1.0.0
sudo docker run -d --name frontend --restart unless-stopped \
  -p 5000:5000 \
  -e BACKEND_URL=http://BACKEND_IP_PLACEHOLDER:5001 \
  -e FLASK_ENV=production \
  211125312702.dkr.ecr.us-west-2.amazonaws.com/project-3tier-web-app-frontend:v1.0.0

echo "Container started"
sudo docker ps | grep frontend
ENDSSH

    # Replace backend IP in the command
    ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no ec2-user@$IP \
        "sudo docker stop frontend && sudo docker rm frontend && \
         sudo docker run -d --name frontend --restart unless-stopped \
         -p 5000:5000 \
         -e BACKEND_URL=http://$BACKEND_IP:5001 \
         -e FLASK_ENV=production \
         211125312702.dkr.ecr.us-west-2.amazonaws.com/project-3tier-web-app-frontend:v1.0.0"
    
    print_info "✓ Fixed $IP"
done

print_step "Waiting 30 seconds for health checks..."
sleep 30

print_step "Checking target health..."
TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
    --query 'TargetGroups[?contains(TargetGroupName, `project-3tier-web-app-fe`)].TargetGroupArn' \
    --output text)

aws elbv2 describe-target-health --region $AWS_REGION \
    --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
    --output table

print_info "Done! Test at: http://project-3tier-web-app-alb-769972739.us-west-2.elb.amazonaws.com"
