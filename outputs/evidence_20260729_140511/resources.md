# Hantt Practical - Live Resource Evidence

Captured: 2026-07-29T14:05:11.352456  |  Region: ap-southeast-2  |  Tag: Project=hantt-practical

| Resource | ID / Name | Detail |
|---|---|---|
| VPC | vpc-05f0938cb4149bd57 | 10.20.0.0/16 |
| Subnet | subnet-07b6c6ac532ec63cb | 10.20.1.0/24 ap-southeast-2a hantt-practical-public-1 |
| Subnet | subnet-0a4505391e47ef22e | 10.20.12.0/24 ap-southeast-2b hantt-practical-private-2 |
| Subnet | subnet-09a432c165ad62558 | 10.20.2.0/24 ap-southeast-2b hantt-practical-public-2 |
| Subnet | subnet-0f403fd5cc75aaa69 | 10.20.11.0/24 ap-southeast-2a hantt-practical-private-1 |
| IGW | igw-0b9633240a01cfd0b | attached to 1 VPC(s) |
| Security Group | sg-0f3c2458ecc6b0bc0 | ingress ports [22, 80, 443] |
| EC2 | i-0e327d3391cc39942 | t3.micro running 54.252.39.1 hantt-practical-nginx |
| EC2 | i-01f5f188f868e8054 | t3.micro running 3.25.54.118 hantt-practical-ami-verify |
| AMI | ami-06b7a47510e14e17f | hantt-nginx-https-1785287779 available |
| Key Pair | hantt-practical-key | rsa |
| IAM Role | hantt-practical-ec2-role | AmazonSSMManagedInstanceCore |
