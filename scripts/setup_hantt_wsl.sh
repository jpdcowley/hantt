# 20260729-0940_004
#!/usr/bin/env bash
# Hantt practical test - WSL2 tooling install + repo scaffold
# Run: bash setup_hantt_wsl.sh

set -euo pipefail

# 256-colour palette
C_STAGE="\033[38;5;45m"    # cyan - stage headers
C_OK="\033[38;5;46m"       # green - success
C_WARN="\033[38;5;214m"    # orange - warnings
C_INFO="\033[38;5;141m"    # purple - info
C_VER="\033[38;5;226m"     # yellow - versions
C_RST="\033[0m"

REPO_DIR="$HOME/hantt"

stage() { echo -e "\n${C_STAGE}==> $1${C_RST}"; }
ok()    { echo -e "${C_OK}    OK: $1${C_RST}"; }
info()  { echo -e "${C_INFO}    $1${C_RST}"; }

stage "1/6 System packages"
sudo apt-get update -qq
sudo apt-get install -y -qq gnupg software-properties-common curl unzip git pipx openssl
ok "base packages installed"

stage "2/6 HashiCorp apt repo (Terraform + Packer)"
if [ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | \
        sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
    sudo apt-get update -qq
    ok "hashicorp repo added"
else
    info "hashicorp repo already present, skipping"
fi
sudo apt-get install -y -qq terraform packer
ok "terraform + packer installed"

stage "3/6 Ansible via pipx (+ Windows support)"
pipx ensurepath > /dev/null 2>&1 || true
if ! pipx list 2>/dev/null | grep -q "package ansible "; then
    pipx install --include-deps ansible
else
    info "ansible already installed via pipx, skipping"
fi
pipx inject ansible pywinrm > /dev/null 2>&1 && ok "pywinrm injected (WinRM transport)" || info "pywinrm already present"
ok "ansible ready"

stage "4/6 AWS CLI check"
if command -v aws > /dev/null 2>&1; then
    info "aws cli present: $(aws --version 2>&1)"
else
    echo -e "${C_WARN}    aws cli not found - installing v2${C_RST}"
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q -o /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install --update
    rm -rf /tmp/aws /tmp/awscliv2.zip
    ok "aws cli v2 installed"
fi

stage "5/6 Repo scaffold at $REPO_DIR"
mkdir -p "$REPO_DIR"/{terraform,ansible/templates,packer,screenshots}
cd "$REPO_DIR"
if [ ! -d .git ]; then
    git init -b main > /dev/null
    ok "git repo initialised (branch: main)"
else
    info "git repo already initialised, skipping"
fi
if [ ! -f .gitignore ]; then
    cat > .gitignore <<'EOF'
.terraform/
*.tfstate
*.tfstate.backup
*.tfvars
.terraform.lock.hcl
*.pem
*.key
crash.log
packer_cache/
EOF
    ok ".gitignore created (state, keys, tfvars excluded)"
fi
if [ ! -f README.md ]; then
    cat > README.md <<'EOF'
# Hantt & Company - Practical Exercise

Terraform + Ansible + Packer: VPC, EC2, nginx over HTTPS (self-signed).

- terraform/ - VPC, subnets, IAM, EC2
- ansible/   - nginx + HTTPS playbook (Linux and Windows)
- packer/    - AMI build reusing the Ansible playbook
- screenshots/ - evidence for deliverables
EOF
    ok "README stub created"
fi

stage "6/6 Versions"
echo -e "${C_VER}    terraform: $(terraform -version | head -1)${C_RST}"
echo -e "${C_VER}    packer:    $(packer -version)${C_RST}"
echo -e "${C_VER}    ansible:   $(~/.local/bin/ansible --version 2>/dev/null | head -1 || ansible --version | head -1)${C_RST}"
echo -e "${C_VER}    git:       $(git --version)${C_RST}"

echo -e "\n${C_OK}All done. Next steps:${C_RST}"
info "1. Create the GitHub repo:  gh repo create hantt --private --source=$REPO_DIR --push"
info "   (or create 'hantt' in the GitHub UI and: git remote add origin git@github.com:<user>/hantt.git)"
info "2. Restart the shell if 'ansible' is not on PATH yet (pipx ensurepath)."