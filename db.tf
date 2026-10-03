# # --- 1. Database Subnet Group ---
# # Groups your isolated database subnets across AZ1 and AZ2 so RDS knows where it can deploy
# resource "aws_db_subnet_group" "db_subnet_group" {
#   name        = "three-tier-db-subnet-group"
#   description = "Database subnet group for high availability multi-az deployment"
#   subnet_ids  = [aws_subnet.pri_ha_db_az1.id, aws_subnet.pri_ha_db_az2.id]

#   tags = {
#     Name = "HA-DB-Subnet-Group"
#   }
# }

# # --- 2. Highly Available Multi-AZ RDS MySQL Instance ---
# resource "aws_db_instance" "three_tier_db" {
#   allocated_storage     = 20
#   max_allocated_storage = 100 # Enables storage auto-scaling
#   engine                = "mysql"
#   engine_version        = "8.0"
#   instance_class        = "db.t3.micro" # Cost-effective for development/testing
#   db_name               = "webappdb"

#   # Secure Variable Interpolation Added Natively
#   username = var.db_username
#   password = var.db_password

#   db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
#   vpc_security_group_ids = [aws_security_group.db_sg.id] # Strictly bound to your security group

#   # CRITICAL HIGH AVAILABILITY CONFIGURATION
#   multi_az = true # Automatically provisions a hot-standby replica in the second AZ

#   backup_retention_period = 7
#   skip_final_snapshot     = true # Set to false for actual production environments

#   tags = {
#     Name = "HA-ThreeTier-Database"
#   }
# }