<!-- 20260729-1940_075 -->
# Issues Encountered & Resolutions

Chronological record of every non-happy-path event during the build, with root cause and fix. Kept as an honest engineering log — several of these are classic WSL2/multi-tool integration traps worth knowing.

## 1. Terraform providers failed to start on WSL2

**Symptom:** `terraform validate` failed for all providers with `Unrecognized remote plugin message / Failed to read any lines from plugin's stdout`, despite correct architecture, permissions, and a healthy binary when executed directly.

**Root cause:** `TMPDIR` pointed at a Windows drive mount (`/mnt/g/wsl-tmp`). Terraform's go-plugin framework binds a unix domain socket in `TMPDIR` for the provider handshake, and drvfs/9p filesystems cannot host unix sockets — `bind: operation not supported`. The provider died before writing its handshake line.

**Diagnosis path:** binary ran fine manually → `TF_LOG=TRACE` exposed the real error (`listen unix /mnt/g/wsl-tmp/plugin…: bind: operation not supported`), which the default error output swallowed.

**Fix:** run Terraform and Packer with a Linux-filesystem TMPDIR — shell aliases `TMPDIR=/tmp terraform` / `TMPDIR=/tmp packer`. Global TMPDIR left untouched for other tooling.

## 2. Windows Administrator password read before it existed

**Symptom:** `terraform output windows_admin_password` → "Output not found", then an empty value immediately after apply.

**Root cause:** the output only exists after the Windows instance is applied, and the password itself is generated during Windows first boot (~5-10 min after the instance reports created).

**Fix:** sequence the password stash after apply plus a boot wait; sanity-check with `${#WIN_ADMIN_PASS}` (expect ~32 chars) before running the playbook.

## 3. Inline vs standalone security group rules conflict

**Symptom:** tightening `admin_cidr` failed mid-apply with `InvalidSecurityGroupRuleId.NotFound` for the WinRM/RDP rules.

**Root cause:** the base SG uses inline `ingress` blocks while the Windows rules were added as standalone `aws_vpc_security_group_ingress_rule` resources. Terraform's inline-rule reconciliation deleted the standalone rules as unmanaged, then the rule resources tried to modify the now-deleted rule ids.

**Fix:** immediate — re-run plan/apply; the refresh dropped the dead ids from state and recreated the rules with the new CIDR. Structural — avoid mixing the two styles on one SG (consolidating into one style is the documented Terraform guidance).

## 4. Packer single-folder config: duplicate blocks

**Symptom:** `packer init .` failed with duplicate `variable` definitions, then duplicate `required_plugins` blocks, once the Windows template joined the folder.

**Root cause:** Packer merges every `*.pkr.hcl` in a directory into one configuration; shared blocks may only be declared once.

**Fix:** shared `packer` and `variable` blocks live in one file; each platform file contains only its `source` and `build`. Builds selected with `packer build -only='hantt-nginx-windows.*' .` and per-platform overrides passed with `-var` (e.g. `instance_type=t3.medium` for Windows).

## 5. Packer→Ansible WinRM: credentials rejected

**Symptom:** Packer's own WinRM communicator connected, but the Ansible provisioner failed immediately: `basic: the specified credentials were rejected by the server`.

**Root cause:** the provisioner invocation passed the WinRM password but no `ansible_user`, so basic auth was attempted without a username.

**Fix:** add `-e ansible_user=Administrator` to the provisioner's `extra_arguments`.

## 6. IAM login profile already existed

**Symptom:** `aws iam create-login-profile` → `EntityAlreadyExists`, and subsequent console automation failed to authenticate.

**Root cause:** the user had been created previously with a different password; `create-login-profile` will not overwrite.

**Fix:** `aws iam update-login-profile` to set the intended password on the existing profile.
