# 20260729-1300_023
# @CST:add:update_5b1c_packer_linux:template
# Bake the Phase 2 Ansible playbook into an Amazon Linux 2023 AMI

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "subnet_id" {
  type        = string
  default     = "subnet-07b6c6ac532ec63cb"
  description = "Public subnet from the Terraform VPC (hantt-practical-public-1)"
}

source "amazon-ebs" "al2023" {
  region        = var.region
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  associate_public_ip_address = true
  ssh_username                = "ec2-user"
  ami_name                    = "hantt-nginx-https-{{timestamp}}"
  ami_description             = "Amazon Linux 2023 with nginx + self-signed HTTPS, baked by Packer + Ansible"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023*-kernel-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  tags = {
    Name      = "hantt-nginx-https"
    Project   = "hantt-practical"
    ManagedBy = "packer"
  }
}

build {
  name    = "hantt-nginx-linux"
  sources = ["source.amazon-ebs.al2023"]

  provisioner "ansible" {
    playbook_file = "../ansible/site.yml"
    groups        = ["nginx_linux"]
    use_proxy     = false
    extra_arguments = [
      "-e", "server_name=localhost",
      "--scp-extra-args", "'-O'"
    ]
  }
}
