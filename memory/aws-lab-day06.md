# Topic: AWS Extended Architecture — Day 06 Practice Lab Artifacts

**Last Updated:** 2026-04-13

---

## Core Concepts

- **Elastic IP (EIP):** IP tĩnh giữ mãi trong account cho đến khi release thủ công. Gắn vào EC2 để stop/start không đổi IP. Unassociated EIP tính $0.005/hr — release ngay nếu không dùng.
- **NAT Gateway:** Đặt ở public subnet, cho phép EC2 private initiate outbound internet (patches, API calls) nhưng không có inbound từ internet. Traffic path: EC2 Private → NAT GW → IGW → internet.
- **OpenVPN EC2:** VPN server trong public subnet. Client connect → traffic đi vào VPC → có thể SSH thẳng vào private IP của EC2 Private. Cần EIP để .ovpn config không đổi sau restart.
- **S3 Public Bucket:** `Principal:*` + `Effect:Allow` + `Action:s3:GetObject` = anonymous read. Cần disable block-public-access trước khi apply policy.
- **S3 Private Bucket + aws:SourceIp:** Deny từ ngoài VPC bằng `NotIpAddress` condition. **Chỉ work khi có VPC Gateway Endpoint** — EC2 trong VPC access S3 qua endpoint → source IP là private IP. Không work với OpenVPN (traffic vẫn ra internet qua NAT GW).
- **Explicit Deny vs Allow:** `Effect:Deny` trong resource-based policy override mọi `Effect:Allow` từ IAM policy — kể cả AdministratorAccess. Không có ngoại lệ (trừ root).

---

## Resources Đã Tạo (ap-northeast-2)

### VPC Base
| Resource         | ID                         | CIDR / Value        |
|------------------|----------------------------|---------------------|
| VPC              | vpc-09c073830f75e7a64       | 10.11.0.0/16        |
| Public Subnet    | subnet-0de3436b0b604076c   | 10.11.0.0/24        |
| Private Subnet   | subnet-0b968a05d1abf68f5   | 10.11.11.0/24       |
| Database Subnet  | subnet-04e1733dedbd958bd   | 10.11.20.0/24       |
| Public RTB       | rtb-052544a20e06010db       | → IGW               |
| Private RTB      | rtb-099967d29949f4f44       | → NAT GW (covers private + database) |

### EC2 Instances
| Name                 | ID                    | Private IP    | Public IP      | Key Pair            |
|----------------------|-----------------------|---------------|----------------|---------------------|
| tin-tt-public-ec2    | i-04c1bb7b517ec5d15   | 10.11.0.146   | 54.180.20.245  | tin-tt-public-kp    |
| tin-tt-private-ec2   | i-034ba398acaa183b5   | 10.11.11.113  | —              | tin-tt-private-kp   |
| tin-tt-database-ec2  | i-0b4bdc16b9362565e   | 10.11.20.6    | —              | tin-tt-database-kp  |
| tin-tt-openvpn       | i-033b9183661bdf6cd   | 10.11.0.151   | 43.203.11.48   | tin-tt-openvpn-kp   |

Key PEM file location: `C:\Users\admin\Downloads\tin-tt-openvpn-kp.pem`

### Networking
| Name               | ID                         | Notes                              |
|--------------------|----------------------------|------------------------------------|
| tin-tt-eip-nat     | eipalloc-0b5b9f9acfec1caae | Gắn vào NAT Gateway                |
| tin-tt-eip-openvpn | 43.203.11.48               | Gắn vào tin-tt-openvpn             |
| tin-tt-nat-gateway | nat-046fd70f043e6e452       | Public subnet, $0.045/hr           |
| tin-tt-openvpn-sg  | sg-07b030604bb741cf4       | UDP 1194, TCP 943/443/22           |
| tin-tt-s3-endpoint | vpce-05c7652532228797f     | S3 Gateway EP, attached cả 2 RTBs  |

### S3
| Name                  | Type    | Status                                     |
|-----------------------|---------|--------------------------------------------|
| tin-tt-public-assets  | Public  | DONE — GetObject:* policy, test.txt uploaded |
| tin-tt-private-assets | Private | Policy applied — bị self-lockout, xem Gotchas |

---

## Key Commands / Config Patterns

```bash
# Tạo EIP với đầy đủ tags
aws ec2 allocate-address \
  --domain vpc \
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=tin-tt-<name>},{Key=Owner,Value=tin_tt},{Key=Email,Value=ttrungtin.work@gmail.com}]'

# Tạo NAT Gateway
aws ec2 create-nat-gateway \
  --subnet-id <public-subnet-id> \
  --allocation-id <eipalloc-id> \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=tin-tt-nat-gateway},{Key=Owner,Value=tin_tt},{Key=Email,Value=ttrungtin.work@gmail.com}]'

# Thêm route 0.0.0.0/0 → NAT GW vào route table
aws ec2 create-route \
  --route-table-id <rtb-id> \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id <nat-id>

# Tạo S3 VPC Gateway Endpoint (free)
aws ec2 create-vpc-endpoint \
  --vpc-id <vpc-id> \
  --service-name com.amazonaws.ap-northeast-2.s3 \
  --route-table-ids <rtb-id-1> <rtb-id-2> \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=tin-tt-s3-endpoint},{Key=Owner,Value=tin_tt},{Key=Email,Value=ttrungtin.work@gmail.com}]'

# S3 private bucket policy (tốt hơn — chỉ deny reads, không deny management)
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyReadOutsideVPC",
    "Effect": "Deny",
    "Principal": "*",
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::tin-tt-private-assets",
      "arn:aws:s3:::tin-tt-private-assets/*"
    ],
    "Condition": {
      "StringNotEquals": {
        "aws:SourceVpc": "vpc-09c073830f75e7a64"
      }
    }
  }]
}

# Fix S3 private bucket từ EC2 (sau khi SSH vào tin-tt-public-ec2)
aws s3api delete-bucket-policy --bucket tin-tt-private-assets
aws s3 cp private.txt s3://tin-tt-private-assets/
# Re-apply policy tốt hơn (chỉ deny reads)

# Delete NAT Gateway (cost hygiene)
aws ec2 delete-nat-gateway --nat-gateway-id nat-046fd70f043e6e452
# Sau đó xóa route trong rtb-099967d29949f4f44
```

---

## Common Gotchas

- **S3 self-lockout:** Apply `Deny s3:*` trước khi upload file → lock out cả management ops (`PutBucketPolicy`, `DeleteBucketPolicy`). Fix: SSH vào EC2 trong VPC → chạy `delete-bucket-policy` từ trong đó (private IP → VPC endpoint → source IP trong 10.11.0.0/16 → Deny không apply).
- **aws:SourceIp với private CIDR:** Không work với OpenVPN. VPN client → OpenVPN EC2 NAT → internet → S3 thấy public IP. Phải dùng VPC Gateway Endpoint + `aws:SourceVpc` (hoặc `aws:SourceIp` nhưng chỉ effective từ EC2 qua endpoint).
- **PowerShell + AWS CLI JSON:** Pass JSON inline trong PowerShell bị mangle quotes → lỗi "MalformedPolicy". Dùng bash terminal hoặc lưu file rồi `--policy file://path.json`.
- **NAT GW tính tiền ngay:** $0.045/hr bắt đầu khi State=available. Delete ngay sau lab nếu không dùng tiếp.

---

## Carry-Over Cần Làm

1. **Fix S3 private bucket** — SSH vào 54.180.20.245 (tin-tt-public-kp), configure AWS CLI, `delete-bucket-policy`, upload `private.txt`, re-apply policy dùng `aws:SourceVpc` thay vì `aws:SourceIp`.
2. **Hoàn thành OpenVPN** — `ssh openvpnas@43.203.11.48 -i tin-tt-openvpn-kp.pem` → wizard → `sudo passwd openvpn` → download `.ovpn` từ `https://43.203.11.48/` → verify SSH vào 10.11.11.113.
3. **Verify NAT GW** — từ EC2 Private: `curl https://google.com` phải succeed.

---

## When To Use This

- Khi cần static IP cho EC2 (EIP pattern)
- Khi private subnet cần outbound internet mà không muốn expose inbound (NAT GW pattern)
- Khi cần engineer access vào private subnet mà không mở SSH ra internet (OpenVPN pattern)
- Khi thiết kế S3 access control: public CDN origin vs private app data

---

## Links to Related Memory Files

- See also: `memory/aws.md` — EC2 lifecycle, S3 ops, VPC/SG/IGW/NAT fundamentals
- See also: `memory/cloud-concepts.md` — IaaS/PaaS/SaaS, AZs, VM vs container
