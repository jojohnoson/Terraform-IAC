# --- Web Server Launch Template ---
resource "aws_launch_template" "web_lt" {
  name_prefix   = "web-server-lt-"
  image_id      = aws_ami_from_instance.custom_ami.id
  instance_type = "t3.micro"
  
  key_name      = "mypassword"

  network_interfaces {
    associate_public_ip_address = true
    # Corrected argument name to cleanly map the security group ID
    security_groups             = [aws_security_group.web_server_sg.id]
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
cat << HTML_EOF > /var/www/html/index.html
  <!DOCTYPE html>
  <html lang="en">
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Web Tier - HA Architecture</title>
      <style>
          body {
              margin: 0;
              padding: 0;
              font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
              background: linear-gradient(135deg, #0f2027 0%, #203a43 50%, #2c5364 100%);
              height: 100vh;
              display: flex;
              justify-content: center;
              align-items: center;
              color: #333;
          }
          .container {
              background-color: #ffffff;
              padding: 50px 60px;
              border-radius: 12px;
              box-shadow: 0 10px 30px rgba(0,0,0,0.3);
              text-align: center;
              max-width: 800px;
              width: 90%;
          }
          h1 {
              margin: 0 0 15px 0;
              font-size: 2.2rem;
              color: #0f2027;
          }
          p {
              margin: 0 0 30px 0;
              font-size: 1.2rem;
              color: #555;
          }
          .server-info {
              background: #f1f5f9;
              border: 1px solid #cbd5e1;
              padding: 15px 20px;
              border-radius: 8px;
              display: inline-block;
          }
          .server-info span {
              display: block;
              font-size: 0.9rem;
              text-transform: uppercase;
              color: #64748b;
              margin-bottom: 5px;
              font-weight: bold;
          }
          .hostname {
              font-family: 'Courier New', Courier, monospace;
              color: #0369a1;
              font-size: 1.3rem;
              font-weight: bold;
          }
      </style>
  </head>
  <body>
      <div class="container">
          <h1>Welcome to the Web Tier</h1>
          <p>Running in High Availability with High Security</p>
          
          <div class="server-info">
              <span>Served by Instance</span>
              <div class="hostname">$(hostname -f)</div>
          </div>
      </div>
  </body>
  </html>
HTML_EOF

# --- INDUSTRY STANDARD CONNECTION MANAGEMENT ---
# Reduce the Keep-Alive timeout to force the browser to establish 
# a new connection to the healthy server during a failover.
sed -i 's/KeepAliveTimeout .*/KeepAliveTimeout 2/' /etc/apache2/apache2.conf
sed -i 's/MaxKeepAliveRequests .*/MaxKeepAliveRequests 50/' /etc/apache2/apache2.conf
systemctl restart apache2
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "HA-Web-Server"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Web Server Auto Scaling Group ---
resource "aws_autoscaling_group" "web_asg" {
  name_prefix         = "web-asg-"
  vpc_zone_identifier = [aws_subnet.pub_ha_az1.id, aws_subnet.pub_ha_az2.id]
  target_group_arns   = [aws_lb_target_group.web_tg.arn]

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  min_size          = 2
  max_size          = 4
  desired_capacity  = 2

  health_check_type         = "ELB"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------------------------------------------------------------

# --- App Server Launch Template ---
resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-server-lt-"
  image_id      = aws_ami_from_instance.custom_ami.id
  instance_type = "t3.micro"

  key_name      = "mypassword"

  network_interfaces {
    associate_public_ip_address = false
    # Corrected argument name to cleanly map the security group ID
    security_groups             = [aws_security_group.app_server_sg.id]
  }

  
  user_data = base64encode(<<-EOF
#!/bin/bash
cat << 'HTML_EOF' > /var/www/html/index.html
  <!DOCTYPE html>
  <html lang="en">
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Web Tier - HA Architecture</title>
      <style>
          body {
              margin: 0;
              padding: 0;
              font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
              background: linear-gradient(135deg, #0f2027 0%, #203a43 50%, #2c5364 100%);
              height: 100vh;
              display: flex;
              justify-content: center;
              align-items: center;
              color: #333;
          }
          .container {
              background-color: #ffffff;
              padding: 50px 60px;
              border-radius: 12px;
              box-shadow: 0 10px 30px rgba(0,0,0,0.3);
              text-align: center;
              max-width: 800px;
              width: 90%;
          }
          h1 {
              margin: 0 0 15px 0;
              font-size: 2.2rem;
              color: #0f2027;
          }
          p {
              margin: 0 0 30px 0;
              font-size: 1.2rem;
              color: #555;
          }
          .server-info {
              background: #f1f5f9;
              border: 1px solid #cbd5e1;
              padding: 15px 20px;
              border-radius: 8px;
              display: inline-block;
          }
          .server-info span {
              display: block;
              font-size: 0.9rem;
              text-transform: uppercase;
              color: #64748b;
              margin-bottom: 5px;
              font-weight: bold;
          }
          .hostname {
              font-family: 'Courier New', Courier, monospace;
              color: #0369a1;
              font-size: 1.3rem;
              font-weight: bold;
          }
      </style>
  </head>
  <body>
      <div class="container">
          <h1>Welcome to the Web Tier</h1>
          <p>Running in High Availability with High Security</p>
          
          <div class="server-info">
              <span>Served by Instance</span>
              <div class="hostname">$(hostname -f)</div>
          </div>
      </div>
  </body>
  </html>
HTML_EOF

# --- INDUSTRY STANDARD CONNECTION MANAGEMENT ---
# Reduce the Keep-Alive timeout to force the browser to establish 
# a new connection to the healthy server during a failover.
sed -i 's/KeepAliveTimeout .*/KeepAliveTimeout 2/' /etc/apache2/apache2.conf
sed -i 's/MaxKeepAliveRequests .*/MaxKeepAliveRequests 50/' /etc/apache2/apache2.conf
systemctl restart apache2
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "HA-App-Server"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- App Server Auto Scaling Group ---
resource "aws_autoscaling_group" "app_asg" {
  name_prefix         = "app-asg-"
  vpc_zone_identifier = [aws_subnet.pri_ha_app_az1.id, aws_subnet.pri_ha_app_az2.id]
  target_group_arns   = [aws_lb_target_group.app_tg.arn]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  min_size          = 2
  max_size          = 4
  desired_capacity  = 2

  health_check_type         = "ELB"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }
}