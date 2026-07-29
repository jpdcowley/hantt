# 20260729-1720_057
# @CST:add:update_8f2a_windows_leg:terraform
# Windows Server 2022 EC2 running the same nginx HTTPS configuration

data "aws_ssm_parameter" "win2022" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

# WinRM ingress for Ansible, restricted to the admin CIDR
resource "aws_vpc_security_group_ingress_rule" "winrm_http" {
  security_group_id = aws_security_group.nginx.id
  description       = "WinRM HTTP (Ansible)"
  from_port         = 5985
  to_port           = 5985
  ip_protocol       = "tcp"
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_ingress_rule" "winrm_https" {
  security_group_id = aws_security_group.nginx.id
  description       = "WinRM HTTPS (Ansible)"
  from_port         = 5986
  to_port           = 5986
  ip_protocol       = "tcp"
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_ingress_rule" "rdp" {
  security_group_id = aws_security_group.nginx.id
  description       = "RDP (troubleshooting)"
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  cidr_ipv4         = var.admin_cidr
}

resource "aws_instance" "nginx_windows" {
  ami                    = data.aws_ssm_parameter.win2022.value
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.nginx.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = aws_key_pair.main.key_name
  get_password_data      = true

  metadata_options {
    http_tokens = "required"
  }

  user_data = <<-EOF
    <powershell>
    # Enable WinRM for Ansible (test environment configuration)
    winrm quickconfig -q
    winrm set winrm/config/service/auth '@{Basic="true"}'
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    New-NetFirewallRule -DisplayName "WinRM 5985" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow
    New-NetFirewallRule -DisplayName "HTTPS 443" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow
    </powershell>
  EOF

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = { Name = "${var.project}-nginx-windows" }
}

output "windows_instance_id" {
  description = "Windows nginx EC2 instance id"
  value       = aws_instance.nginx_windows.id
}

output "windows_public_ip" {
  description = "Windows nginx EC2 public IP"
  value       = aws_instance.nginx_windows.public_ip
}

output "windows_admin_password" {
  description = "Decrypted Administrator password (sensitive)"
  value       = rsadecrypt(aws_instance.nginx_windows.password_data, tls_private_key.ssh.private_key_pem)
  sensitive   = true
}
