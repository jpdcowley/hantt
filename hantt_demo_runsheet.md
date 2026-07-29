<!-- 20260729-1940_075 -->
# Build Runsheet — Full Stack From Scratch (Happy Path)

Fastest known-good sequence to recreate the entire stack in a fresh AWS account from a clean WSL2 environment. Each step assumes the previous succeeded. Approximate total: **~60 minutes**, of which ~35 is unattended bake/boot time.

## 0. Workstation setup (~5 min)

```bash
# tooling: Terraform + Packer (HashiCorp apt repo), Ansible (pipx), AWS CLI v2
bash setup_hantt_wsl.sh          # idempotent installer; scaffolds the repo layout

# Windows management collections
ansible-galaxy collection install chocolatey.chocolatey ansible.windows community.windows

# WSL2 note: ensure TMPDIR points at a Linux filesystem for terraform/packer
# (go-plugin cannot bind unix sockets on Windows drive mounts)
alias terraform="TMPDIR=/tmp terraform"
alias packer="TMPDIR=/tmp packer"
```

AWS CLI must be configured with credentials able to create VPC/EC2/IAM resources.

## 1. Infrastructure (~3 min)

```bash
cd terraform
echo "admin_cidr = \"$(curl -s https://checkip.amazonaws.com)/32\"" > terraform.tfvars
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

Creates: VPC, 2 public + 2 private subnets, IGW, routing, security group, IAM role/profile, key pair, Linux EC2 (AL2023), Windows EC2 (Server 2022). Note the outputs: `instance_public_ip`, `windows_public_ip`.

## 2. Configure Linux (~2 min)

```bash
cd ../ansible
# inventory.ini [nginx_linux] host = instance_public_ip from step 1
ansible-playbook -i inventory.ini site.yml
curl -k https://<instance_public_ip>        # expect HTTP 200
```

## 3. Configure Windows (~10 min, mostly first-boot wait)

Wait ~5-10 min after apply for Windows first boot to complete (password generation + WinRM user_data), then:

```bash
cd ../terraform
echo "export WIN_ADMIN_PASS='$(TMPDIR=/tmp terraform output -raw windows_admin_password)'" > ~/.secrets/hantt.env
chmod 600 ~/.secrets/hantt.env && source ~/.secrets/hantt.env
# sanity: echo ${#WIN_ADMIN_PASS} should print ~32

cd ../ansible
# inventory.ini [nginx_windows] host = windows_public_ip from step 1
ansible-playbook -i inventory.ini windows.yml
curl -k https://<windows_public_ip>         # expect HTTP 200
```

## 4. Bake AMIs (~10 min Linux, ~25 min Windows, can run in parallel terminals)

```bash
cd ../packer
packer init .
packer build -only='hantt-nginx-linux.*' .
packer build -only='hantt-nginx-windows.*' -var instance_type=t3.medium .
```

Record both `ami-...` ids.

Timing expectations for the Windows build: "Waiting for WinRM to become available..." is the long pole — Windows first boot plus user_data execution takes **5-10 minutes** before WinRM connects (the 15-minute `winrm_timeout` allows for slow boots). The Ansible run and AMI snapshot add roughly another 10-15 minutes.

Note: the Windows provisioner must pass `ansible_user=Administrator` explicitly in `extra_arguments` — Packer supplies the WinRM password to Ansible but not the username, and basic auth fails with "credentials were rejected" without it (see Issues log #5). The committed template already includes this.

## 5. Verify the Linux AMI (~2 min)

```bash
cd ../scripts
python3 verify_ami.py               # launches from the AMI, polls HTTPS, expect 200 with zero config
python3 verify_ami.py --terminate   # clean up when done
```

(Update `AMI_ID` in the script if the baked AMI id differs.)

## 6. Reference outputs

```bash
python3 gather_evidence.py          # writes resources.json / resources.md / https_check.txt under outputs/
```

## 7. Teardown

```bash
cd ../terraform
terraform destroy
# AMIs + snapshots are outside Terraform state:
aws ec2 deregister-image --image-id <ami-id> --region ap-southeast-2
aws ec2 delete-snapshot --snapshot-id <snap-id> --region ap-southeast-2
```
