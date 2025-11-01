# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# IAM Policy for EC2 Instances
resource "aws_iam_role_policy" "ec2_policy" {
  name = "${var.project_name}-ec2-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach SSM policy for Session Manager access
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "${var.project_name}-ec2-profile"
  }
}

# Frontend EC2 Instances (in Public Subnets)
resource "aws_instance" "frontend" {
  count                  = length(var.public_subnet_cidrs)
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name

  user_data = var.use_ecr_deployment ? templatefile("${path.module}/../scripts/user_data_frontend_v2.sh", {
    backend_url        = "http://${aws_instance.backend[0].private_ip}:5001"
    ecr_frontend_repo  = data.aws_ecr_repository.frontend.repository_url
    image_tag          = var.image_tag
  }) : templatefile("${path.module}/../scripts/user_data_frontend.sh", {
    backend_url = "http://${aws_instance.backend[0].private_ip}:5001"
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-frontend-${count.index + 1}"
    Tier = "Frontend"
  }

  depends_on = [aws_nat_gateway.main]
}

# Backend EC2 Instances (in Private Subnets)
resource "aws_instance" "backend" {
  count                  = length(var.private_subnet_cidrs)
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name

  user_data = var.use_ecr_deployment ? templatefile("${path.module}/../scripts/user_data_backend_v2.sh", {
    db_host           = aws_db_instance.main.address
    db_name           = var.db_name
    db_username       = var.db_username
    db_password       = var.db_password
    ecr_backend_repo  = data.aws_ecr_repository.backend.repository_url
    image_tag         = var.image_tag
  }) : templatefile("${path.module}/../scripts/user_data_backend.sh", {
    db_host     = aws_db_instance.main.address
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-backend-${count.index + 1}"
    Tier = "Backend"
  }

  depends_on = [aws_db_instance.main, aws_nat_gateway.main]
}
