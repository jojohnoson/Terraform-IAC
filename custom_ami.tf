resource "aws_instance" "base_server" {
  ami                         = "ami-07a00cf47dbbc844c"#It is a Ubuntu 22.04 image in ap-south-1 region
  instance_type               = "t3.micro"
  subnet_id                   = "subnet-087b7c97df70b4c84"
  vpc_security_group_ids      = ["sg-00ffccebd3db961e0"]
  associate_public_ip_address = true 

user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2
              systemctl enable apache2
              systemctl start apache2
              EOF

  # Forces Terraform to wait until "Initializing" changes to "2/2 checks passed"
  provisioner "local-exec" {
    command = <<EOF
      echo "Waiting for instance ${self.id} to pass all AWS Status Checks..."
      aws ec2 wait instance-status-ok --instance-ids ${self.id} --region ap-south-1
      echo "Instance is 100% healthy and initialized. Proceeding to AMI baking."
    EOF
  }

  tags = {
    Name = "base-server"
  }
}

resource "aws_ami_from_instance" "custom_ami" {
  name               = "custom-al2023-ha-app-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  source_instance_id = aws_instance.base_server.id
  
  # Ensure the instance file system is cleanly paused during snapshotting
  snapshot_without_reboot = false 

  # ADDED: Tagging block for the custom AMI
  tags = {
    Name        = "Custom-AMI-HA-WEB"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}