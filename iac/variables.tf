variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID"
  type        = string
  default     = "ami-0554aa6767e249943"
}

variable "key_pair_name" {
  description = "Name for the generated AWS key pair"
  type        = string
  default     = "terraform-ec2-key"
}

variable "private_key_filename" {
  description = "Local file to store private key"
  type        = string
  default     = "private_key.pem"
}

variable "security_group_name" {
  description = "Name of security group"
  type        = string
  default     = "terraform-ec2-sg"
}

variable "instance_name" {
  description = "Name tag for EC2 instance"
  type        = string
  default     = "Terraform-EC2-AmazonLinux-Docker"
}
