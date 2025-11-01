#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting frontend environment setup..."

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Install AWS CLI v2 (if not already installed)
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

# Get AWS region from instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)

# Fallback if metadata service fails
if [ -z "$REGION" ]; then
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
fi

echo "AWS Region: $REGION"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# ECR repository details
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
FRONTEND_IMAGE="${ecr_frontend_repo}"
IMAGE_TAG="${image_tag}"

echo "ECR Registry: $ECR_REGISTRY"
echo "Frontend Image: $FRONTEND_IMAGE:$IMAGE_TAG"

echo "Logging into ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "Pulling frontend Docker image..."
docker pull $FRONTEND_IMAGE:$IMAGE_TAG

echo "Creating systemd service for frontend container..."
cat > /etc/systemd/system/frontend-container.service << EOF
[Unit]
Description=Frontend Container Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker stop frontend
ExecStartPre=-/usr/bin/docker rm frontend
ExecStart=/usr/bin/docker run --name frontend \\
  --rm \\
  -p 5000:5000 \\
  -e BACKEND_URL=${backend_url} \\
  -e FLASK_ENV=production \\
  $FRONTEND_IMAGE:$IMAGE_TAG
ExecStop=/usr/bin/docker stop frontend

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable frontend-container.service
systemctl start frontend-container.service

# Setup log rotation
cat > /etc/logrotate.d/frontend-container << 'EOF'
/var/log/frontend-container.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF

echo "Frontend environment setup completed successfully!"
echo "Container status:"
docker ps | grep frontend || echo "Container starting..."
