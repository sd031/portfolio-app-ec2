#!/bin/bash

# Fix backend instances through frontend bastion

set -e

export AWS_PROFILE=personal_new
AWS_REGION="us-west-2"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Get IPs
FRONTEND_IP=$(aws ec2 describe-instances --region $AWS_REGION \
    --filters "Name=tag:Name,Values=project-3tier-web-app-frontend-1" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

BACKEND_IPS=$(aws ec2 describe-instances --region $AWS_REGION \
    --filters "Name=tag:Name,Values=project-3tier-web-app-backend-*" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].PrivateIpAddress' \
    --output text)

# Get DB endpoint
cd terraform
DB_HOST=$(terraform output -raw rds_endpoint 2>/dev/null | cut -d: -f1)
DB_NAME=$(terraform output -raw rds_database_name 2>/dev/null)
cd ..

print_info "Frontend IP (bastion): $FRONTEND_IP"
print_info "Backend IPs: $BACKEND_IPS"
print_info "DB Host: $DB_HOST"

# Copy SSH key to frontend (bastion)
print_step "Setting up bastion..."
scp -i 3tier-app-key.pem -o StrictHostKeyChecking=no 3tier-app-key.pem ec2-user@$FRONTEND_IP:/tmp/
ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no ec2-user@$FRONTEND_IP "chmod 400 /tmp/3tier-app-key.pem"

# Fix each backend instance
for BACKEND_IP in $BACKEND_IPS; do
    print_step "Fixing backend at $BACKEND_IP..."
    
    # Create fix script
    cat > /tmp/fix-backend-remote.sh << 'EOF'
#!/bin/bash
BACKEND_IP=$1
DB_HOST=$2
DB_NAME=$3

echo "Connecting to backend $BACKEND_IP..."

ssh -i /tmp/3tier-app-key.pem -o StrictHostKeyChecking=no ec2-user@$BACKEND_IP << 'ENDSSH'
# Get region and ECR details
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)

echo "Logging into ECR..."
aws ecr get-login-password --region "$REGION" | sudo docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

echo "Stopping old container..."
sudo docker stop backend 2>/dev/null || true
sudo docker rm backend 2>/dev/null || true

echo "Pulling backend image..."
sudo docker pull 211125312702.dkr.ecr.us-west-2.amazonaws.com/project-3tier-web-app-backend:v1.0.0

echo "Starting backend container..."
sudo docker run -d --name backend --restart unless-stopped \
  -p 5001:5001 \
  -e DB_HOST=DB_HOST_PLACEHOLDER \
  -e DB_NAME=DB_NAME_PLACEHOLDER \
  -e DB_USER=admin \
  -e DB_PASSWORD=MySecurePassword123! \
  -e FLASK_ENV=production \
  211125312702.dkr.ecr.us-west-2.amazonaws.com/project-3tier-web-app-backend:v1.0.0

echo "Checking container..."
sudo docker ps | grep backend

echo "Testing health endpoint..."
sleep 5
curl -f http://localhost:5001/health || echo "Health check failed"
ENDSSH
EOF

    # Upload and execute
    scp -i 3tier-app-key.pem -o StrictHostKeyChecking=no /tmp/fix-backend-remote.sh ec2-user@$FRONTEND_IP:/tmp/
    ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no ec2-user@$FRONTEND_IP \
        "chmod +x /tmp/fix-backend-remote.sh && \
         sed -i 's/DB_HOST_PLACEHOLDER/$DB_HOST/g' /tmp/fix-backend-remote.sh && \
         sed -i 's/DB_NAME_PLACEHOLDER/$DB_NAME/g' /tmp/fix-backend-remote.sh && \
         /tmp/fix-backend-remote.sh $BACKEND_IP $DB_HOST $DB_NAME"
    
    print_info "✓ Fixed backend at $BACKEND_IP"
done

print_step "Testing backend from frontend..."
ssh -i 3tier-app-key.pem -o StrictHostKeyChecking=no ec2-user@$FRONTEND_IP \
    "for IP in $BACKEND_IPS; do echo \"Testing \$IP:\"; curl -s http://\$IP:5001/health; echo; done"

print_info "Done! Backend should now be accessible."
