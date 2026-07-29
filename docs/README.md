<!-- 20260729-1940_075 -->
# nginx-on-AWS: Terraform + Ansible + Packer

Infrastructure-as-code stack that provisions an isolated AWS network and delivers an nginx web server over HTTPS, using three complementary tools with a single source of configuration truth:

- **Terraform** builds the infrastructure: VPC, subnets, routing, security, IAM, and compute — a Linux web server and a Windows Server web server.
- **Ansible** configures both servers: nginx installation, TLS certificate, hardened HTTPS vhost — over SSH for Linux, WinRM for Windows, from a shared set of templates.
- **Packer** bakes the same Ansible configuration into reusable AMIs (Linux and Windows) for immutable, zero-touch deployments.

## Architecture

```
                        VPC 10.20.0.0/16 (ap-southeast-2)
  ┌────────────────────────────────────────────────────────────┐
  │  Public subnets                     Private subnets        │
  │  10.20.1.0/24  (AZ a)               10.20.11.0/24 (AZ a)   │
  │  10.20.2.0/24  (AZ b)               10.20.12.0/24 (AZ b)   │
  │        │                            (reserved for future   │
  │        │                             backend tiers)        │
  │  ┌─────┴──────────┐   ┌────────────────────┐               │
  │  │ EC2 t3.micro   │   │ EC2 t3.medium      │               │
  │  │ Amazon Linux   │   │ Windows Server     │               │
  │  │ 2023 + nginx   │   │ 2022 + nginx       │               │
  │  └────────────────┘   └────────────────────┘               │
  │     SG: 80/443 public; 22/5985/5986/3389 admin CIDR only   │
  │     IAM role: SSM managed core (both instances)            │
  │        │                                                   │
  └────────┼───────────────────────────────────────────────────┘
           ▼
     Internet Gateway ── HTTPS (TLS 1.2/1.3, self-signed)
```

Design notes:

- Public and private subnet pairs span two availability zones. The web tier runs public; the private pair is defined and routed for future backend expansion without re-architecting.
- The instance role carries `AmazonSSMManagedInstanceCore`, enabling Session Manager access as a fallback to SSH and keeping the door open for Systems Manager patching.
- IMDSv2 is enforced and the root volume is gp3 with encryption at rest.
- TLS uses a self-signed certificate generated at configuration time; swapping in an ACM certificate behind an ALB, or Let's Encrypt with a public domain, is the intended production path.

## Repository layout

```
terraform/   VPC, subnets, IGW, routing, security group, IAM, key pair, EC2
ansible/     site.yml playbook + Jinja2 templates (nginx vhost, index page)
packer/      HCL2 template baking the Ansible playbook into an AL2023 AMI
scripts/     operational tooling (AMI launch verification)
logs/        resource inventory and run logs
outputs/     generated reference reports of the live environment
```

## Prerequisites

- Terraform >= 1.5, Packer >= 1.10, Ansible >= 2.15 (with `pywinrm` for Windows targets)
- AWS CLI v2 configured with credentials for the target account
- Python 3.11+ with `boto3` for the operational scripts

## Usage

### 1. Provision infrastructure

```bash
cd terraform
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

Outputs include the instance public IP/DNS and the path to the generated SSH private key (written locally with 0600 permissions and excluded from version control).

### 2. Configure the servers

```bash
cd ansible
# Linux over SSH
ansible-playbook -i inventory.ini site.yml

# Windows over WinRM (Administrator password sourced from the environment,
# retrieved via: terraform output -raw windows_admin_password)
source ~/.secrets/hantt.env
ansible-playbook -i inventory.ini windows.yml
```

Both playbooks are idempotent: package installation, certificate generation, config templating, and service management all converge safely on re-runs. Configuration is validated with `nginx -t` before the service starts. The Windows playbook installs nginx and OpenSSL via Chocolatey and serves the same templated index page.

### 3. Bake the AMIs

```bash
cd packer
packer init .
packer build -only='hantt-nginx-linux.*' .
packer build -only='hantt-nginx-windows.*' -var instance_type=t3.medium .
```

The folder is a single Packer configuration: shared plugin and variable blocks live in the Linux file, each platform contributes its own `source`/`build`. Packer launches a temporary builder, runs the **same** playbook used for live configuration (`site.yml` / `windows.yml`), and produces a tagged AMI per platform. Instances launched from these AMIs serve HTTPS immediately with no post-launch configuration. A production Windows image would add an EC2Launch sysprep step for unique SIDs and hostnames.

### 4. Verify an AMI-based instance

```bash
cd scripts
python3 verify_ami.py              # launch from the AMI, poll HTTPS, report
python3 verify_ami.py --terminate  # clean up the verification instance
```

### 5. Reference outputs

Each run of the reporting tooling writes a timestamped folder under `outputs/` capturing the live state of the environment:

- `resources.json` — full API-level detail of every project-tagged resource (VPC, subnets, gateway, routing, security group, instances, AMIs, key pair, IAM role) as returned by AWS at capture time.
- `resources.md` — a condensed, human-readable reference table of the same inventory.
- `https_check.txt` — HTTPS response status, headers, and body from the running web server(s), confirming end-to-end TLS service.

These reference reports provide a point-in-time record of what the stack deployed and how it responded, useful for reviews, change comparisons, and compliance records without console access.

## Configuration

Key Terraform variables (see `terraform/variables.tf`):

| Variable | Default | Purpose |
|---|---|---|
| `region` | `ap-southeast-2` | Deployment region |
| `vpc_cidr` | `10.20.0.0/16` | VPC address space |
| `instance_type` | `t3.micro` | Web server size |
| `admin_cidr` | `0.0.0.0/0` | CIDR permitted on SSH; restrict to a fixed IP for production |

## Security posture

- No credentials, private keys, or state files are committed; `.gitignore` enforces this.
- The SSH key pair is generated by Terraform per environment and stays local. The Windows Administrator password is generated by AWS at first boot, decrypted via the same key pair, and referenced by Ansible through an environment variable — never stored in the repository.
- Web ports (80/443) are public; administrative ports (SSH 22, WinRM 5985/5986, RDP 3389) are restricted to `admin_cidr`, set to a single /32 via an uncommitted tfvars file.
- Both instances enforce IMDSv2 and use encrypted gp3 root volumes.
- The self-signed certificate provides transport encryption out of the box; certificate trust is a deliberate follow-up (ACM/ALB or ACME) rather than a gap in the design.

## Teardown

```bash
cd terraform
terraform destroy
```

AMIs and their snapshots are created outside Terraform state; deregister the AMI and delete its snapshot separately when retiring an image.
