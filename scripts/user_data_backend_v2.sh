#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting backend environment setup..."

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
BACKEND_IMAGE="${ecr_backend_repo}"
IMAGE_TAG="${image_tag}"

echo "ECR Registry: $ECR_REGISTRY"
echo "Backend Image: $BACKEND_IMAGE:$IMAGE_TAG"

echo "Logging into ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "Pulling backend Docker image..."
docker pull $BACKEND_IMAGE:$IMAGE_TAG

# Wait for RDS to be available (retry logic)
echo "Waiting for database to be available..."
for i in {1..30}; do
    if docker run --rm $BACKEND_IMAGE:$IMAGE_TAG python -c "import mysql.connector; mysql.connector.connect(host='${db_host}', user='${db_username}', password='${db_password}')" 2>/dev/null; then
        echo "Database is ready!"
        break
    fi
    echo "Attempt $i: Database not ready, waiting..."
    sleep 10
done

echo "Creating systemd service for backend container..."
cat > /etc/systemd/system/backend-container.service << EOF
[Unit]
Description=Backend Container Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker stop backend
ExecStartPre=-/usr/bin/docker rm backend
ExecStart=/usr/bin/docker run --name backend \\
  --rm \\
  -p 5001:5001 \\
  -e DB_HOST=${db_host} \\
  -e DB_NAME=${db_name} \\
  -e DB_USER=${db_username} \\
  -e DB_PASSWORD=${db_password} \\
  -e FLASK_ENV=production \\
  $BACKEND_IMAGE:$IMAGE_TAG
ExecStop=/usr/bin/docker stop backend

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable backend-container.service
systemctl start backend-container.service

# Setup log rotation
cat > /etc/logrotate.d/backend-container << 'EOF'
/var/log/backend-container.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF

echo "Backend environment setup completed successfully!"
echo "Container status:"
docker ps | grep backend || echo "Container starting..."
