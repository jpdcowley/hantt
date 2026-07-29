# 20260729-1005_005
# @CST:add:update_9c2e_tf_vpc:outputs

output "vpc_id" {
  description = "VPC id"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet ids"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet ids"
  value       = aws_subnet.private[*].id
}

output "instance_id" {
  description = "nginx EC2 instance id"
  value       = aws_instance.nginx.id
}

output "instance_public_ip" {
  description = "nginx EC2 public IP (Ansible target)"
  value       = aws_instance.nginx.public_ip
}

output "instance_public_dns" {
  description = "nginx EC2 public DNS"
  value       = aws_instance.nginx.public_dns
}

output "private_key_path" {
  description = "Path to the generated SSH private key"
  value       = local_file.private_key.filename
}
