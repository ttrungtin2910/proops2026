---
name: Networking Basics
description: DNS resolution chain, port table, firewall rules, TLS handshake, and connectivity debug checklist
type: user
---

# Networking Basics for DevOps

---

## 1. DNS Resolution Chain

### What DNS is
DNS maps a human-readable hostname (app.example.com) to an IP address (203.0.113.42).
Every network connection starts here. A broken DNS entry means nothing works,
regardless of whether the server itself is healthy.

### Full resolution chain (cold — no cache)

```
Browser
  |
  | 1. Check local caches (in order):
  |    - Browser DNS cache (chrome://net-internals/#dns)
  |    - OS DNS cache (systemd-resolve --statistics)
  |    - /etc/hosts file (always checked before DNS queries)
  |    Hit? Skip to TCP. Miss? Continue down.
  |
  v
OS stub resolver
  | Reads /etc/resolv.conf -> finds recursive resolver (e.g. 8.8.8.8)
  |
  v
Recursive Resolver (8.8.8.8)
  | "I'll look this up for you."
  | Checks its own cache. If miss:
  |
  v
Root Nameservers (13 clusters, hardcoded in resolvers)
  | Query: "Who handles .com?"
  | Response: NS records for .com TLD -> a.gtld-servers.net, ...
  |
  v
.com TLD Nameservers (gtld-servers.net)
  | Query: "Who handles example.com?"
  | Response: NS records -> ns1.example.com, ns2.example.com
  |           + glue records: ns1.example.com -> 205.251.196.1
  |           (glue prevents chicken-and-egg when NS is under same domain)
  |
  v
Authoritative Nameserver (ns1.example.com)
  | "I own example.com. Here is the answer."
  | Query: "What is app.example.com?"
  | Response: A record -> 203.0.113.42   TTL: 300
  |
  v
Recursive resolver caches answer for TTL=300 seconds
  |
  v
Browser receives: app.example.com -> 203.0.113.42
```

### DNS record types

| Type | Purpose | Example |
|---|---|---|
| A | IPv4 address | app.example.com -> 203.0.113.42 |
| AAAA | IPv6 address | app.example.com -> 2001:db8::1 |
| CNAME | Alias to another hostname | app.example.com -> alb-123.us-east-1.elb.amazonaws.com |
| MX | Mail server | example.com -> mail.example.com |
| TXT | Arbitrary text (SPF, DKIM, verification) | "v=spf1 include:..." |
| NS | Authoritative nameservers for zone | example.com -> ns1.example.com |
| PTR | Reverse DNS (IP -> hostname) | 42.113.0.203.in-addr.arpa -> app.example.com |

### Common DNS failure modes

**Stale TTL after migration:**
```
Old TTL: 86400 (24 hours). You update A record to new IP.
Users who resolved in the last 24 hours still hit old server.
Fix: lower TTL to 300 at least 24h BEFORE any migration. Raise it back after.
```

**NXDOMAIN — record missing:**
```
dig app.example.com -> status: NXDOMAIN
Cause: record never created, typo in hostname, wrong zone
```

**CNAME to deleted resource:**
```
app.example.com -> alb-123.us-east-1.elb.amazonaws.com -> (no A record)
Cause: load balancer deleted, CNAME not updated
Browser: DNS_PROBE_FINISHED_NXDOMAIN
```

### Diagnostic commands
```bash
dig app.example.com                       # standard query
dig +short app.example.com                # just the IP
dig @8.8.8.8 app.example.com             # query specific resolver
dig app.example.com +trace                # full chain from root to authoritative
dig app.example.com CNAME                 # check for CNAME
nslookup app.example.com 8.8.8.8         # alternative to dig
```

---

## 2. Port Table — 10 Essential Ports

```
Port   Protocol  Service               DevOps Rule
-----  --------  --------------------  ---------------------------------------------------
22     TCP       SSH                   Restrict to specific IPs (VPN/bastion only).
                                       Open to 0.0.0.0/0 = critical security finding.

53     UDP/TCP   DNS                   UDP for queries, TCP for large responses/zone transfers.
                                       Blocked port 53 = DNS fails = everything fails.

80     TCP       HTTP                  Should only exist to redirect to 443.
                                       Serving real content on 80 in prod = misconfiguration.

443    TCP       HTTPS / TLS           All production web traffic. First port to check
                                       in any web outage. Must be open to 0.0.0.0/0.

3306   TCP       MySQL                 Never expose to internet. App subnet -> DB subnet only.
                                       Open to 0.0.0.0/0 = immediate security incident.

5432   TCP       PostgreSQL            Same rule as MySQL. Private subnets only.
                                       Check this in every new environment audit.

6379   TCP       Redis                 No auth by default in older versions.
                                       Exposed Redis = data exfiltration + RCE risk.
                                       Internal network only, always.

8080   TCP       HTTP alt / app        Common default for Node.js, Tomcat, Spring Boot.
                                       Should never be internet-facing without a
                                       reverse proxy (nginx/ALB) in front.

9090   TCP       Prometheus            Exposes internal service topology and metrics.
                                       Internal network only. Also: Grafana=3000,
                                       Alertmanager=9093.

2379   TCP       etcd (K8s)            Stores all cluster state: secrets, configs,
2380   TCP       etcd peer             service accounts. Exposed etcd = full cluster
                                       compromise. Control plane nodes only.
```

**Kubernetes-specific ports:**
```
6443   TCP   Kubernetes API server    kubectl talks here. Admin IPs only.
10250  TCP   kubelet API              Control plane -> nodes only.
30000- TCP   NodePort range           Avoid exposing directly; use Ingress instead.
32767
```

**Mental model for security group audits:**
```
Internet-facing (intentional):  80, 443
Management (restricted IPs):    22, 6443
Internal only (never internet): 3306, 5432, 6379, 9090, 2379, 8080

Finding any "internal only" port open to 0.0.0.0/0 = P0 security incident.
```

---

## 3. Firewall and Security Group Rules

### Stateless vs Stateful

**Stateless** — evaluates every packet independently. No memory of prior packets.
Must write rules for BOTH directions of every connection.

**Stateful** — tracks TCP connection state. Remembers that a connection was established
and automatically allows return traffic without an explicit rule.

AWS Security Groups, GCP Firewall Rules, and iptables with conntrack are all stateful.

### How stateful works in practice

```
Inbound rule: ALLOW TCP from 0.0.0.0/0 to port 443

Browser sends SYN to port 443:
  Firewall: inbound rule matches -> ALLOW
  Records connection state: {browser:54821 <-> server:443, ESTABLISHED}

Server sends SYN-ACK back (outbound):
  Firewall: looks up connection table -> found, ESTABLISHED -> ALLOW
  No outbound rule needed — state table approves return traffic automatically

Server sends HTTP response (outbound):
  Firewall: connection table -> ESTABLISHED -> ALLOW automatically
```

**Practical implication:**
```
For traffic arriving AT your server:
  Write an INBOUND rule.
  Return traffic (server responding) is automatic. No outbound rule needed.

For traffic your server INITIATES to other services:
  Write an OUTBOUND rule on your server's security group.
  Write an INBOUND rule on the destination's security group.
  Both required — stateful handles the returns, not the initiation.
```

### Inbound vs outbound — which rule applies when

```
INBOUND:  browser -> your server port 443      inbound rule on server SG
          internet -> your server port 22       inbound rule on server SG

OUTBOUND: your server -> RDS port 5432         outbound rule on server SG
                                                inbound rule on RDS SG
          your server -> api.stripe.com:443    outbound rule on server SG
          your server -> apt.ubuntu.com:80     outbound rule on server SG
```

Most common mistake:
```
Server can't reach database:
  Check 1: outbound rule on server SG allows TCP 5432
  Check 2: inbound rule on RDS SG allows TCP 5432 from server SG
  Both must exist. Stateful handles the return traffic from the DB.
```

### Connection tracking timeout
```
Firewall removes idle connections from state table after a timeout.
AWS NAT Gateway: 350 seconds idle timeout for TCP.
ALB:             60 seconds idle timeout (configurable).

If connection sits idle longer than timeout:
  Firewall drops it from state table.
  Next packet from either side: no state found -> dropped silently.
  Application sees: connection open but data never arrives.
  Result: hanging connections, read timeouts.

Fix: enable TCP keepalives on long-lived connections.
  Linux: sysctl net.ipv4.tcp_keepalive_time=60
  App:   configure keepalive in DB connection pool and HTTP client.
```

### DROP vs REJECT
```
DROP:   packet silently discarded, no response sent.
        Caller waits until timeout (75s for TCP).
        Looks like: curl hangs, nc times out.

REJECT: packet discarded, RST or ICMP "unreachable" sent back.
        Caller fails immediately.
        Looks like: "Connection refused", immediate error.

Hanging = DROP = stateful firewall blocking silently.
Immediate refusal = REJECT or nothing listening on port.
```

---

## 4. TLS Handshake

### What TLS establishes
```
1. Authentication  — server proves it owns the hostname (via CA-signed certificate)
2. Key exchange    — both sides derive shared encryption keys without sending them
3. Cipher agreement — which algorithms to use (AES-256-GCM, ChaCha20, etc.)
```

### TLS 1.3 handshake sequence (1 RTT)
```
Client                                    Server
  |                                          |
  |------- ClientHello ---------------------->|
  |  TLS version: 1.3                        |
  |  Supported ciphers: AES_256_GCM_SHA384   |
  |  Client key share (X25519 public key)    |
  |  SNI: app.example.com  <- plaintext      |
  |  Session ticket (if resuming)            |
  |                                          |
  |<------ ServerHello -----------------------|
  |  Chosen cipher: AES_256_GCM_SHA384       |
  |  Server key share (X25519 public key)    |
  |  [all below is now encrypted]            |
  |                                          |
  |<------ Certificate -----------------------|
  |  CN/SAN: app.example.com                 |
  |  Issuer: Let's Encrypt R3                |
  |  Valid: 2026-01-01 to 2026-04-01         |
  |                                          |
  |<------ CertificateVerify ----------------  |
  |  Signature proving server owns the key   |
  |                                          |
  |<------ Finished -------------------------  |
  |  HMAC of entire handshake                |
  |                                          |
  |------- Finished -------------------------  |
  |  HMAC of entire handshake                |
  |                                          |
Session keys derived. Encryption active. HTTP data flows.
```

### Certificate trust chain
```
Browser ships with ~150 trusted root CA certs (pre-installed by OS/browser vendor)

Root CA (ISRG Root X1)          <- in every browser's root store
  |  signs
Intermediate CA (Let's Encrypt R3)
  |  signs
End-entity cert (app.example.com)  <- presented by server

Browser validates:
  1. Is signature on app.example.com cert valid? (R3 signed it?)   YES
  2. Is signature on R3 cert valid? (ISRG Root X1 signed it?)      YES
  3. Is ISRG Root X1 in my trusted root store?                      YES
  4. Does CN or SAN match app.example.com?                          YES
  5. Is today within NotBefore..NotAfter?                           YES
  6. Is cert revoked? (OCSP check)                                  NO
  -> chain of trust established -> server authenticated
```

### Three common certificate errors

**1. Expired — NET::ERR_CERT_DATE_INVALID**
```
Not After: 2026-04-01. Today: 2026-04-06. Hard block, no user bypass.
Fix: auto-renew with certbot timer or AWS ACM.
Alert: 30 days, 14 days, 7 days before expiry.
```

**2. Hostname mismatch — NET::ERR_CERT_COMMON_NAME_INVALID**
```
Cert covers: www.example.com
Request to:  app.example.com -> NO SAN match -> hard block

Common causes:
  - Wildcard *.example.com does NOT cover app.sub.example.com (one level only)
  - Wrong cert deployed to wrong server
  - SNI misconfigured: server serves default cert regardless of requested hostname
  
Fix: add app.example.com as a SAN on the cert.
Note: browsers check SAN only — CN field is ignored by Chrome/Firefox.
```

**3. Self-signed — NET::ERR_CERT_AUTHORITY_INVALID**
```
Issuer == Subject (cert signed itself, not by a trusted CA).
User can click "Advanced -> Proceed" (unlike expired/mismatch).
Appropriate for: internal services with private CA, local dev.
Never for:       user-facing HTTPS endpoints.
```

### Debug TLS with openssl

```bash
# Full TLS connection — shows cert chain, cipher, validity
openssl s_client -connect app.example.com:443 \
  -servername app.example.com \
  </dev/null 2>/dev/null

# Human-readable cert details — the most useful command
openssl s_client -connect app.example.com:443 \
  -servername app.example.com \
  </dev/null 2>/dev/null \
  | openssl x509 -noout -text

# Key fields to read in output:
#   Validity -> Not Before / Not After  (is cert expired?)
#   Subject Alternative Name            (does hostname appear here?)
#   Issuer                              (self-signed if issuer == subject)
#   Basic Constraints: CA:FALSE         (correct for server cert)

# Just the expiry date
echo | openssl s_client -connect app.example.com:443 \
  -servername app.example.com 2>/dev/null \
  | openssl x509 -noout -enddate
# notAfter=Apr  1 00:00:00 2026 GMT

# Just the SANs — does the cert cover your hostname?
echo | openssl s_client -connect app.example.com:443 \
  -servername app.example.com 2>/dev/null \
  | openssl x509 -noout -text \
  | grep -A2 "Subject Alternative Name"
# DNS:app.example.com, DNS:*.example.com

# Days until expiry — paste into monitoring scripts
echo | openssl s_client -connect app.example.com:443 \
  -servername app.example.com 2>/dev/null \
  | openssl x509 -noout -checkend 2592000  # 2592000 = 30 days in seconds
# "Certificate will expire" or "Certificate will not expire"

# Check chain is complete and trusted
echo | openssl s_client -connect app.example.com:443 \
  -servername app.example.com 2>/dev/null \
  | grep "Verify return code"
# Verify return code: 0 (ok)                    <- good
# Verify return code: 10 (certificate has expired)
# Verify return code: 18 (self signed certificate)
# Verify return code: 62 (hostname mismatch)
```

---

## 5. Connectivity Debug Checklist

When a service is unreachable, run these four commands in this exact order.
Each one tests a different layer. The first command that fails tells you the layer.

```
Layer 3 (IP routing)  -> ping
Layer 4 (TCP port)    -> nc / telnet
Layer 7 (DNS + path)  -> dig
Layer 7 (path trace)  -> traceroute
```

### Step 1: dig — confirm DNS resolves to the right IP

```bash
dig +short app.example.com
# Expected: 203.0.113.42
# NXDOMAIN or empty = DNS problem (wrong record, propagation lag, deleted zone)

# Full resolution chain if something looks wrong
dig app.example.com +trace

# Compare what different resolvers return (catch stale caches)
dig @8.8.8.8 app.example.com
dig @1.1.1.1 app.example.com
```

What it tells you:
```
Correct IP returned  -> DNS is fine, move to Step 2
NXDOMAIN             -> Record missing or wrong name
Wrong IP             -> Stale cache (TTL not expired), or DNS record not updated
CNAME to dead target -> Resource was deleted, CNAME not updated
```

### Step 2: nc (netcat) — test TCP port connectivity

```bash
nc -zv -w 5 app.example.com 443
# -z = scan mode (connect and close)
# -v = verbose output
# -w 5 = timeout after 5 seconds
```

What each output means:
```
"Connection to app.example.com 443 port succeeded!"
  -> TCP works. Port is open. Problem is TLS or application layer.
  -> Next: openssl s_client to check TLS.

"Connection refused" (immediate)
  -> Server received SYN, sent RST. Nothing listening on port 443.
  -> App crashed, wrong port in LB config, or listening on 0.0.0.0 vs 127.0.0.1.
  -> Check: ss -tlnp | grep 443

"Operation timed out" (after 5 seconds)
  -> SYN sent, no response. Packet silently dropped.
  -> Firewall/security group missing inbound TCP 443 rule.
  -> This is the DROP case (stateful firewall blocking).
```

Isolate which port is blocked:
```bash
nc -zv -w 5 app.example.com 80    # is HTTP also blocked?
nc -zv -w 5 app.example.com 22    # is SSH open? (proves TCP routing works)
# If 22 works but 443 doesn't: security group missing rule for 443 specifically
```

### Step 3: traceroute — find where packets stop

```bash
# Default (ICMP) — some routers block ICMP probes
traceroute app.example.com

# TCP mode — uses actual TCP SYN to port 443, more firewall-friendly
traceroute -T -p 443 app.example.com    # Linux
# Windows: tracert app.example.com
```

Reading the output:
```
 1  192.168.1.1    1ms    <- your router
 2  10.0.0.1       8ms    <- ISP edge
 3  72.14.209.1   11ms    <- ISP backbone
 4  108.170.246.1 12ms    <- cloud provider backbone
 5  * * *                 <- no response from this hop onward
 6  * * *
```

What `* * *` means:
```
Option A: firewall between hop 4 and destination is dropping packets (including ICMP TTL exceeded)
Option B: router doesn't respond to ICMP but forwards TCP normally
          -> switch to TCP mode: traceroute -T -p 443 app.example.com
Option C: traffic reaches destination but firewall drops it there

If TCP mode also shows * * * at the same hop:
  -> that hop is blocking TCP port 443
  -> this is your security group or NACL
```

Sudden large latency jump (e.g. 12ms -> 180ms):
```
Geographic hop (continent crossing) or congested link.
Latency going DOWN at a later hop: asymmetric routing — normal, not a problem.
```

### Step 4: openssl s_client — test TLS (only if TCP succeeded)

```bash
# Run only after nc confirms port 443 is open
openssl s_client -connect app.example.com:443 \
  -servername app.example.com \
  </dev/null 2>/dev/null \
  | grep -E "Verify return code|subject|issuer|notAfter"
```

What each result means:
```
Verify return code: 0 (ok)
  -> TLS is fine. Problem is application layer (HTTP 5xx, app crash).
  -> Next: curl -v https://app.example.com

Verify return code: 10 (certificate has expired)
  -> Renew cert immediately.

Verify return code: 18 (self signed certificate)
  -> Self-signed cert in production. Replace with CA-signed cert.

Verify return code: 62 (hostname mismatch)
  -> Wrong cert deployed. Check SAN: openssl x509 -noout -text | grep SAN
```

---

## Decision Tree: "Ping Works but curl Hangs"

```
ping 203.0.113.42 succeeds
  -> Layer 3 (IP routing) is working
  -> ping proves: IP reachable, ICMP allowed
  -> ping proves nothing about: port 443, TLS, application

curl https://app.example.com hangs (timeout, not immediate error)
  -> TCP SYN is sent
  -> No SYN-ACK received
  -> Packet is being silently DROPPED (firewall DROP rule)

Diagnosis path:
  dig +short app.example.com          -> correct IP? Yes -> DNS fine
  nc -zv -w 5 app.example.com 443     -> times out -> firewall blocking 443
  nc -zv -w 5 app.example.com 22      -> succeeds  -> routing fine, just 443 blocked
  traceroute -T -p 443 app.example.com -> * * * at cloud firewall hop

Fix: add inbound TCP 443 rule to security group
  aws ec2 authorize-security-group-ingress \
    --group-id sg-0123456789abcdef0 \
    --protocol tcp --port 443 --cidr 0.0.0.0/0
```

---

## Quick Reference

```bash
# DNS
dig +short app.example.com
dig app.example.com +trace
dig @8.8.8.8 app.example.com

# Port connectivity
nc -zv -w 5 app.example.com 443
nc -zv -w 5 app.example.com 22

# Path tracing
traceroute -T -p 443 app.example.com

# TLS inspection
openssl s_client -connect app.example.com:443 -servername app.example.com </dev/null 2>/dev/null | openssl x509 -noout -enddate
openssl s_client -connect app.example.com:443 -servername app.example.com </dev/null 2>/dev/null | openssl x509 -noout -text | grep -A2 "Subject Alternative Name"

# Full HTTP test with timing
curl -sv -o /dev/null -w "\nStatus: %{http_code} | DNS: %{time_namelookup}s | Connect: %{time_connect}s | TLS: %{time_appconnect}s | Total: %{time_total}s\n" \
  https://app.example.com
```
