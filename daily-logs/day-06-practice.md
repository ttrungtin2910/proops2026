# Daily Log — Tin (Trần Trung Tín) — Day 6 Extended Practice (Actual) — 2026-04-13

## Today's Assignment
- [x] Step 1 — Elastic IP: allocate và associate vào EC2 Public
- [x] Step 2 — NAT Gateway: tạo ở public subnet, update route tables private + database
- [x] Step 3 — OpenVPN EC2: launch từ Marketplace AMI, gắn EIP, configure SG
- [x] Step 4 — S3 Public Bucket: tạo, disable block-public-access, attach GetObject policy, verify URL
- [x] Step 5 — S3 Private Bucket: tạo + policy xong, nhưng bị self-lockout — cần fix từ EC2
- [x] OpenVPN wizard + .ovpn download — launched nhưng chưa hoàn thành setup

## Environment
AWS CLI (bash) + AWS Console — ap-northeast-2.
Base VPC: vpc-09c073830f75e7a64 / 10.11.0.0/16
Subnets: tin-tt-public-subnet (subnet-0de3436b0b604076c), tin-tt-private-subnet (subnet-0b968a05d1abf68f5), tin-tt-database-subnet (subnet-04e1733dedbd958bd)
Route tables: tin-tt-public-rtb (rtb-052544a20e06010db), tin-tt-private-rtb (rtb-099967d29949f4f44)

## Naming + Tagging Rules Applied Today
Tất cả resource tạo hôm nay đều gắn:
  Key=Name,Value=tin-tt-<resource>
  Key=Owner,Value=tin_tt
  Key=Email,Value=ttrungtin.work@gmail.com

## Completed

### Step 1 — Elastic IP trên EC2 Public
- Allocated: eipalloc-0a06bcabef256db19 (tin-tt không đặt name cho EIP này)
- Associated: i-04c1bb7b517ec5d15 (tin-tt-public-ec2)
- EC2 Public giờ có static IP — stop/start không đổi địa chỉ.
- Concept: EIP được giữ trong account cho đến khi release thủ công. Không gắn vào instance đang chạy → tính tiền $0.005/hr.

### Step 2 — NAT Gateway
- EIP mới cho NAT: eipalloc-0b5b9f9acfec1caae (tin-tt-eip-nat)
- NAT Gateway: nat-046fd70f043e6e452 (tin-tt-nat-gateway) tại subnet-0de3436b0b604076c
- Route thêm vào rtb-099967d29949f4f44: 0.0.0.0/0 → nat-046fd70f043e6e452
- tin-tt-private-rtb cover 2 subnets (private + database) → chỉ cần add route 1 lần.
- Concept: NAT GW cho phép EC2 private initiate outbound nhưng internet không initiate inbound được (không có public IP, không có route vào).

### Step 3 — OpenVPN EC2
- AMI: ami-08d306d776874be6a (OpenVPN Access Server Community Image, 2026-03-17)
- SG: sg-07b030604bb741cf4 (tin-tt-openvpn-sg) — UDP 1194, TCP 943, TCP 443, TCP 22
- EC2: i-033b9183661bdf6cd (tin-tt-openvpn) tại subnet-0de3436b0b604076c
- EIP: 43.203.11.48 (tin-tt-eip-openvpn), key: tin-tt-openvpn-kp.pem
- User SSH vào OpenVPN: ssh -i tin-tt-openvpn-kp.pem openvpnas@43.203.11.48
- Chưa hoàn thành wizard và chưa download .ovpn → carry-over sang ngày mai.

### Step 4 — S3 Public Bucket
- Bucket: tin-tt-public-assets (ap-northeast-2)
- Disable block-public-access: BlockPublicAcls=false, IgnorePublicAcls=false, BlockPublicPolicy=false, RestrictPublicBuckets=false
- Policy: Effect=Allow, Principal=*, Action=s3:GetObject, Resource=arn:aws:s3:::tin-tt-public-assets/*
- Upload test.txt (chạy từ bash terminal — xem issue bên dưới)
- Verify URL: https://tin-tt-public-assets.s3.ap-northeast-2.amazonaws.com/test.txt → trả về "hello from s3 - tin-tt" không cần credentials.

### Step 5 — S3 Private Bucket (partial)
- Bucket: tin-tt-private-assets (ap-northeast-2), block-public-access: all true
- Policy: Effect=Deny, Principal=*, Action=s3:*, NotIpAddress aws:SourceIp 10.11.0.0/16
- VPC Gateway Endpoint: vpce-05c7652532228797f (tin-tt-s3-endpoint) — attached to cả 2 route tables
- Status: bucket + policy tạo xong. Xem BLOCKED bên dưới.

## Issues Encountered

### Issue 1 — PowerShell không pass JSON vào AWS CLI
Triệu chứng: `aws s3api put-bucket-policy --policy '{"Version":...}'` → lỗi "MalformedPolicy: invalid Json"
Nguyên nhân: PowerShell mangle quotes khi truyền string vào external process.
Đã thử: single-quote string, $variable, ConvertTo-Json, backtick escape — tất cả đều fail.
Fix: chạy từ bash terminal (Claude Code shell) — single-quoted JSON hoạt động bình thường.
Bài học: Với AWS CLI trên Windows, nếu cần pass JSON inline → dùng bash hoặc lưu ra file rồi dùng `file://`.

### Issue 2 — S3 private bucket self-lockout
Tình huống: Apply policy `Deny s3:*` trước khi upload test file.
Hậu quả: Policy block hết mọi thứ từ ngoài VPC bao gồm cả `PutBucketPolicy` và `DeleteBucketPolicy`. Laptop không thể manage bucket dù IAM permission đúng (explicit Deny overrides IAM Allow).
Thậm chí `delete-bucket-policy` cũng bị deny: "explicit deny in a resource-based policy".
Fix path: SSH vào tin-tt-public-ec2 (54.180.20.245) → configure AWS CLI → delete policy → upload file → re-apply policy tốt hơn (chỉ deny reads, không deny management ops).

### Issue 3 — aws:SourceIp 10.11.0.0/16 không work với OpenVPN
Nguyên nhân: `aws:SourceIp` trong S3 bucket policy check IP của HTTP request tới S3.
Khi laptop connect VPN → traffic tới S3 đi qua: VPN client → OpenVPN EC2 (NAT) → internet → S3.
S3 thấy source IP là EIP của OpenVPN hoặc NAT GW — không phải private IP 10.11.x.x.
Điều kiện `aws:SourceIp: 10.11.0.0/16` chỉ work khi EC2 trong VPC access S3 qua VPC Gateway Endpoint.
Fix: đã tạo VPC Gateway Endpoint. Test đúng phải là: SSH vào EC2 Private → `aws s3 ls` (succeed), laptop không VPN → denied.

## Resources Created Today
| Name                   | Type              | ID                         |
|------------------------|-------------------|----------------------------|
| (no name)              | Elastic IP        | eipalloc-0a06bcabef256db19 |
| tin-tt-eip-nat         | Elastic IP        | eipalloc-0b5b9f9acfec1caae |
| tin-tt-eip-openvpn     | Elastic IP        | (associated to OpenVPN EC2)|
| tin-tt-nat-gateway     | NAT Gateway       | nat-046fd70f043e6e452      |
| tin-tt-openvpn-sg      | Security Group    | sg-07b030604bb741cf4       |
| tin-tt-openvpn         | EC2 Instance      | i-033b9183661bdf6cd        |
| tin-tt-public-assets   | S3 Bucket         | (public read)              |
| tin-tt-private-assets  | S3 Bucket         | (VPC-only deny policy)     |
| tin-tt-s3-endpoint     | VPC Gateway EP    | vpce-05c7652532228797f     |

## Not Completed
| Item                        | Reason                                  | Days Overdue |
|-----------------------------|-----------------------------------------|--------------|
| OpenVPN wizard + .ovpn      | Launched EC2 nhưng chưa SSH setup       | 0 (today)    |
| S3 private bucket test file | Self-lockout — cần fix từ EC2           | 0 (today)    |
| Publish IRD-001             | Lab tiêu hết thời gian                  | 11 ngày      |
| Linear training issue       | Blocked on IRD-001                      | 11 ngày      |
| feat/w1-* branch            | Blocked on Linear issue                 | 11 ngày      |

## Artifacts Built Today
- [x] `daily-logs/day-06-practice.md` — file này
- [x] `daily-reports/day-06-practice-report.md` — summary report

## How I Used Claude Code Today
Thực hành hoàn toàn bằng AWS CLI với Claude hỗ trợ generate lệnh đã điền sẵn IDs thực.
Hiệu quả nhất: Claude detect được self-lockout ngay lập tức và giải thích tại sao `aws:SourceIp` với private CIDR cần VPC endpoint.
Quan trọng nhất học được hôm nay:
  - Explicit Deny trong resource-based policy là tuyệt đối — không có IAM allow nào override được.
  - `aws:SourceIp` với private CIDR không liên quan đến VPN — chỉ liên quan đến VPC Gateway Endpoint.
  - Policy design phải nghĩ trước: nếu Deny s3:* thì management ops cũng bị khóa.

## Self Score
- Completion: 6/10 (3 steps hoàn chỉnh, 2 steps partial, carry-over vẫn còn)
- Understanding: 9/10 (các concept S3 policy + VPC endpoint hiểu rõ hơn qua việc bị lỗi thực tế)
- Energy: 7/10

## One Thing I Learned Today That Surprised Me
`aws:SourceIp` với private IP range trong S3 bucket policy KHÔNG hoạt động chỉ với VPN.
Tôi nghĩ rằng khi connect VPN, traffic sẽ đi qua VPC và source IP sẽ là private.
Thực tế: VPN client gửi traffic qua internet đến OpenVPN EC2, EC2 đó NAT ra ngoài → S3 thấy public IP.
Private IP range trong `aws:SourceIp` chỉ work khi có VPC Gateway Endpoint — traffic đi hoàn toàn trong AWS network, không ra internet, và source IP là private IP của EC2.

---

## Tomorrow's Context Block

**Where I am:** Day 6 Extended Practice xong. Architecture đã có: EIP trên EC2 Public, NAT Gateway cho private/database subnets, OpenVPN EC2 launched (chưa setup xong), S3 public bucket (hoạt động), S3 private bucket (policy đúng nhưng bị lockout — cần fix từ EC2), VPC S3 Gateway Endpoint đã tạo.

**Priority ngày mai:**
  1. SSH vào tin-tt-public-ec2 (54.180.20.245, key: tin-tt-public-kp.pem) → fix S3 private bucket
  2. Hoàn thành OpenVPN: ssh openvpnas@43.203.11.48 → wizard → sudo passwd openvpn → download .ovpn
  3. Publish IRD-001 via /write-ird
  4. Tạo Linear issue via /create-linear-issue
  5. Check Day 7 brief

**Cost hygiene:** NAT Gateway (nat-046fd70f043e6e452) tính $0.045/hr. Delete nếu không cần cho lab tiếp theo.
