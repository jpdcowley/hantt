# 20260729-1005_005
# @CST:add:update_9c2e_tf_vpc:variables

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "project" {
  description = "Project tag / name prefix"
  type        = string
  default     = "hantt-practical"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ (defined for future use)"
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for the nginx host"
  type        = string
  default     = "t3.micro"
}

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH/HTTPS (tighten to your IP/32 for extra credit)"
  type        = string
  default     = "0.0.0.0/0"
}
