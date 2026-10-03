data "http" "my_public_ip" {
  url = "https://ipv4.icanhazip.com" # This specific URL only returns IPv4
}
# ============================================================================================
# 1. BASTION HOST SECURITY GROUP (The Edge Entry Point for Administration)
# ============================================================================================
resource "aws_security_group" "bastion_sg" {
  name        = "Bastion-Host-SG"
  description = "Allows SSH access to the admin jump box from administrator IP"
  vpc_id      = aws_vpc.ha_vpc.id

  ingress {
    description = "SSH from Administrator Location Only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_public_ip.response_body)}/32"]
  }

  egress {
    description = "Allow All Outbound Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Bastion-Host-SG" }
}

# ============================================================================================
# 2. EXTERNAL APPLICATION LOAD BALANCER SECURITY GROUP (Public Traffic Entry)
# ============================================================================================
resource "aws_security_group" "external_alb_sg" {
  name        = "External-ALB-SG"
  description = "Allows public internet access to the frontend entry point"
  vpc_id      = aws_vpc.ha_vpc.id

  ingress {
    description = "Public HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to the world to access your React frontend
  }

  egress {
    description = "Allow All Outbound Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "External-ALB-SG" }
}

# ============================================================================================
# 3. WEB SERVER SECURITY GROUP (Public Subnets - Web Tier)
# ============================================================================================
resource "aws_security_group" "web_server_sg" {
  name        = "Web-Server-SG"
  description = "Accepts HTTP from external ALB and SSH from Bastion"
  vpc_id      = aws_vpc.ha_vpc.id

  # APPLICATION TRAFFIC
  ingress {
    description     = "HTTP from External ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.external_alb_sg.id] # Tied to External ALB
  }

  # ADMINISTRATIVE TRAFFIC
  ingress {
    description     = "SSH from Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Tied to Bastion
  }
  # ALLOW PINGS FROM ANYWHERE ON THE INTERNET (Like Google)
  ingress {
    description = "Allow ICMP Pings from Everyone"
    from_port   = -1  # Opens all ICMP types
    to_port     = -1  # Opens all ICMP codes
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"] # Open to the entire world
  }

  egress {
    description = "Allow All Outbound Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Web-Server-SG" }
}

# ============================================================================================
# 4. INTERNAL APPLICATION LOAD BALANCER SECURITY GROUP (Private App Subnets Entry)
# ============================================================================================
resource "aws_security_group" "internal_alb_sg" {
  name        = "Internal-ALB-SG"
  description = "Private gateway to application logic"
  vpc_id      = aws_vpc.ha_vpc.id

  ingress {
    description     = "HTTP from Web Servers"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server_sg.id] # Accepts traffic only from Web Tier
  }

  egress {
    description = "Allow All Outbound Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Internal-ALB-SG" }
}

# ============================================================================================
# 5. APP SERVER SECURITY GROUP (Private Subnets - App Tier)
# ============================================================================================
resource "aws_security_group" "app_server_sg" {
  name        = "App-Server-SG"
  description = "Accepts Node.js from internal ALB and SSH from Bastion"
  vpc_id      = aws_vpc.ha_vpc.id

  # APPLICATION TRAFFIC
  ingress {
    description     = "Node.js port from Internal ALB"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb_sg.id] # Tied to Internal ALB
  }

  # ADMINISTRATIVE TRAFFIC
  ingress {
    description     = "SSH from Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Tied to Bastion
  }

  egress {
    description = "Allow All Outbound Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "App-Server-SG" }
}

# ============================================================================================
# 6. DATABASE SECURITY GROUP (Isolated Subnets - DB Tier)
# ============================================================================================
resource "aws_security_group" "db_sg" {
  name        = "DB-SG"
  description = "Accepts MySQL from App Servers and SSH from Bastion"
  vpc_id      = aws_vpc.ha_vpc.id

  # APPLICATION TRAFFIC
  ingress {
    description     = "MySQL from App Servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_server_sg.id] # Tied strictly to App Tier
  }

  # ADMINISTRATIVE TRAFFIC (Optional but helpful if troubleshooting the DB via Bastion tunnel)
  ingress {
    description     = "SSH from Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Tied to Bastion
  }

  egress {
    description = "Allow All Outbound Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "DB-SG" }
}