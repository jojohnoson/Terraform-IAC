# --- 1. External ALB Target Group ---
# This tracks the health of your Web Servers on Port 80
resource "aws_lb_target_group" "web_tg" {
  name        = "Web-Server-TG"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.ha_vpc.id
  target_type = "instance"

  # ADD THIS LINE RIGHT HERE:
  deregistration_delay = 5

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "80"
    
    # 2. Minimum allowed AWS values for hyper-fast failover
    interval            = 5  # Check every 5 seconds (Minimum allowed)
    timeout             = 2  # Fail if no response in 2 seconds
    healthy_threshold   = 2  # Mark healthy after 2 successes
    unhealthy_threshold = 2  # Mark DEAD after 2 failures (Minimum allowed)
  }

  tags = { Name = "Web-Server-TG" }
}

# --- 2. The External Application Load Balancer ---
# Placed in the public subnets to intercept internet traffic
resource "aws_lb" "external_alb" {
  name               = "External-Public-ALB"
  internal           = false # public-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.external_alb_sg.id]
  subnets            = [aws_subnet.pub_ha_az1.id, aws_subnet.pub_ha_az2.id]
  
  # 3. Set a reasonable idle timeout for user sessions (e.g., 15 minutes)
  idle_timeout       = 15


  tags = { Name = "External-Public-ALB" }
}

# --- 3. External ALB HTTP Listener ---
# Listens on Port 80 and forwards to the Web Server Target Group
resource "aws_lb_listener" "external_http" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

#--------------------------------------------------------------------------------------------

# --- 1. Internal ALB Target Group ---
# This tracks the health of your Backend App Servers on Port 4000
resource "aws_lb_target_group" "app_tg" {
  name        = "App-Server-TG"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.ha_vpc.id
  target_type = "instance"

# ADD THIS LINE RIGHT HERE:
  deregistration_delay = 5
  
  health_check {
    path                = "/health" # Or your app's health endpoint
    protocol            = "HTTP"
    port                = "4000"
    # 2. Minimum allowed AWS values for hyper-fast failover
    interval            = 5  # Check every 5 seconds (Minimum allowed)
    timeout             = 2  # Fail if no response in 2 seconds
    healthy_threshold   = 2  # Mark healthy after 2 successes
    unhealthy_threshold = 2  # Mark DEAD after 2 failures (Minimum allowed)
  }

  tags = { Name = "App-Server-TG" }
}

# --- 2. The Internal Application Load Balancer ---
# Placed inside private app subnets—completely invisible to the public internet
resource "aws_lb" "internal_alb" {
  name               = "Internal-Private-ALB"
  internal           = true # Hidden inside the VPC
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb_sg.id]
  subnets            = [aws_subnet.pri_ha_app_az1.id, aws_subnet.pri_ha_app_az2.id]

  tags = { Name = "Internal-Private-ALB" }
}

# --- 3. Internal ALB Listener ---
# Listens on Port 80 inside the network and forwards to the App Target Group (Port 4000)
resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
