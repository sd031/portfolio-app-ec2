# Application Load Balancer
resource "aws_lb" "frontend_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  enable_http2              = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for Frontend Instances
resource "aws_lb_target_group" "frontend" {
  name     = "${var.project_name}-fe-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.project_name}-frontend-tg"
  }
}

# Register Frontend Instances with Target Group
resource "aws_lb_target_group_attachment" "frontend" {
  count            = length(aws_instance.frontend)
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend[count.index].id
  port             = 5000
}

# ALB Listener - HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Optional: ALB Listener - HTTPS (uncomment and configure with ACM certificate)
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.frontend_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
#   certificate_arn   = "arn:aws:acm:region:account-id:certificate/certificate-id"
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.frontend.arn
#   }
# }
