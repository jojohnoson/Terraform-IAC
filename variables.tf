variable "db_username" {
  type        = string
  description = "The master username for the database"
  default     = "admin"
}

variable "db_password" {
  type        = string
  description = "The master password for the database"
  sensitive   = true # Hides the value from CLI output logs
}