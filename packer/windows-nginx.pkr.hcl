# 20260729-1910_072
# @CST:add:update_6c4d_windows_ami:template
# Bake the Windows Ansible playbook into a Windows Server 2022 AMI
# Mirrors linux-nginx.pkr.hcl: same subnet, same tags, same playbook-as-source-of-truth

variable "winrm_password" {
  type        = string
  default     = "PackerBu1ld-Temp!"
  description = "Temporary Administrator password used only during the build"
  sensitive   = true
}

source "amazon-ebs" "win2022" {
  region        = var.region
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  associate_public_ip_address = true
  ami_name                    = "hantt-nginx-https-windows-{{timestamp}}"
  ami_description             = "Windows Server 2022 with nginx + self-signed HTTPS, baked by Packer + Ansible"

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.winrm_password
  winrm_timeout  = "15m"

  user_data = <<-EOF
    <powershell>
    # Temporary build credentials + WinRM for the Packer communicator
    net user Administrator "${var.winrm_password}"
    winrm quickconfig -q
    winrm set winrm/config/service/auth '@{Basic="true"}'
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    New-NetFirewallRule -DisplayName "WinRM 5985" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow
    </powershell>
  EOF

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  tags = {
    Name      = "hantt-nginx-https-windows"
    Project   = "hantt-practical"
    ManagedBy = "packer"
  }
}

build {
  name    = "hantt-nginx-windows"
  sources = ["source.amazon-ebs.win2022"]

  provisioner "ansible" {
    playbook_file = "../ansible/windows.yml"
    groups        = ["nginx_windows"]
    use_proxy     = false
    extra_arguments = [
      "-e", "ansible_connection=winrm",
      "-e", "ansible_port=5985",
      "-e", "ansible_winrm_transport=basic",
      "-e", "ansible_winrm_server_cert_validation=ignore",
      "-e", "ansible_user=Administrator",
      "-e", "ansible_password=${var.winrm_password}"
    ]
  }
}
