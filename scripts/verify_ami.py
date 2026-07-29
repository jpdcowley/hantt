# 20260729-1415_033
#!/usr/bin/env python3
"""Launch a test EC2 from the Packer-baked AMI and verify HTTPS serves with zero configuration.

Usage:
    python3 verify_ami.py                 # launch + verify
    python3 verify_ami.py --terminate     # terminate the verify instance afterwards
"""

import argparse
import builtins
import re
import ssl
import sys
import time
import urllib.request
from datetime import datetime
from pathlib import Path

import boto3

# @CST:add:update_2f8d_verify_log:logging
LOG_DIR = Path(__file__).resolve().parent.parent / "logs"
LOG_FILE = LOG_DIR / f"verify_ami_{datetime.now():%Y%m%d_%H%M%S}.log"
ANSI_RE = re.compile(r"\033\[[0-9;]*m")
_orig_print = builtins.print


def print(*args, **kwargs):
    """Tee every print to console (with colour) and log file (colour stripped)."""
    _orig_print(*args, **kwargs)
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        line = " ".join(str(a) for a in args)
        with open(LOG_FILE, "a") as fh:
            fh.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} {ANSI_RE.sub('', line)}\n")
    except OSError:
        pass

REGION = "ap-southeast-2"
AMI_ID = "ami-06b7a47510e14e17f"
SUBNET_ID = "subnet-07b6c6ac532ec63cb"
SG_ID = "sg-0f3c2458ecc6b0bc0"
KEY_NAME = "hantt-practical-key"
TAG_NAME = "hantt-practical-ami-verify"

C_STAGE = "\033[38;5;45m"
C_OK = "\033[38;5;46m"
C_WARN = "\033[38;5;214m"
C_INFO = "\033[38;5;141m"
C_RST = "\033[0m"

ec2 = boto3.client("ec2", region_name=REGION)


def find_verify_instance():
    """Return the running/pending verify instance id, or None."""
    resp = ec2.describe_instances(
        Filters=[
            {"Name": "tag:Name", "Values": [TAG_NAME]},
            {"Name": "instance-state-name", "Values": ["pending", "running"]},
        ]
    )
    for res in resp["Reservations"]:
        for inst in res["Instances"]:
            return inst["InstanceId"]
    return None


def launch():
    print(f"{C_STAGE}==> Launching test instance from {AMI_ID}{C_RST}")
    resp = ec2.run_instances(
        ImageId=AMI_ID,
        InstanceType="t3.micro",
        MinCount=1,
        MaxCount=1,
        KeyName=KEY_NAME,
        NetworkInterfaces=[{
            "DeviceIndex": 0,
            "SubnetId": SUBNET_ID,
            "Groups": [SG_ID],
            "AssociatePublicIpAddress": True,
        }],
        TagSpecifications=[{
            "ResourceType": "instance",
            "Tags": [
                {"Key": "Name", "Value": TAG_NAME},
                {"Key": "Project", "Value": "hantt-practical"},
            ],
        }],
    )
    instance_id = resp["Instances"][0]["InstanceId"]
    print(f"{C_OK}    instance: {instance_id}{C_RST}")

    print(f"{C_STAGE}==> Waiting for running state...{C_RST}")
    ec2.get_waiter("instance_running").wait(InstanceIds=[instance_id])

    desc = ec2.describe_instances(InstanceIds=[instance_id])
    public_ip = desc["Reservations"][0]["Instances"][0]["PublicIpAddress"]
    print(f"{C_OK}    public IP: {public_ip}{C_RST}")
    return instance_id, public_ip


def check_https(public_ip, attempts=18, delay=5):
    """Poll HTTPS until nginx responds. Self-signed cert, so verification is disabled."""
    print(f"{C_STAGE}==> Waiting for nginx over HTTPS (up to {attempts * delay}s)...{C_RST}")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    url = f"https://{public_ip}/"
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(url, context=ctx, timeout=5) as resp:
                status = resp.status
                body = resp.read().decode(errors="replace")
                print(f"{C_OK}    HTTP {status} after attempt {attempt} - zero-touch AMI verified!{C_RST}")
                title = body.split("<title>")[1].split("</title>")[0] if "<title>" in body else "n/a"
                print(f"{C_INFO}    page title: {title}{C_RST}")
                return True
        except Exception:
            time.sleep(delay)
    print(f"{C_WARN}    no response after {attempts * delay}s - retry: curl -kI {url}{C_RST}")
    return False


def terminate():
    instance_id = find_verify_instance()
    if not instance_id:
        print(f"{C_WARN}    no verify instance found - nothing to terminate{C_RST}")
        return
    print(f"{C_STAGE}==> Terminating {instance_id}{C_RST}")
    ec2.terminate_instances(InstanceIds=[instance_id])
    ec2.get_waiter("instance_terminated").wait(InstanceIds=[instance_id])
    print(f"{C_OK}    terminated - meter stopped{C_RST}")


def main():
    parser = argparse.ArgumentParser(description="Verify the Packer-baked nginx HTTPS AMI")
    parser.add_argument("--terminate", action="store_true", help="terminate the verify instance and exit")
    args = parser.parse_args()

    if args.terminate:
        terminate()
        return

    existing = find_verify_instance()
    if existing:
        print(f"{C_WARN}    verify instance already running: {existing} - terminate first or reuse it{C_RST}")
        sys.exit(1)

    instance_id, public_ip = launch()
    ok = check_https(public_ip)
    print(f"{C_INFO}    screenshot: browser -> https://{public_ip}{C_RST}")
    print(f"{C_INFO}    cleanup:    python3 verify_ami.py --terminate{C_RST}")
    print(f"{C_INFO}    log:        {LOG_FILE}{C_RST}")
    sys.exit(0 if ok else 2)


if __name__ == "__main__":
    main()