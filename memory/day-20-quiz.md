Q1: Difference between a Docker image and a Docker container? When does a container exit with code 0 vs 137?
A1: Docker image is what we build base on Dockerfile, docker container is the implement services base on Docker image with specific config like port, env, mount. Exit code 0 is container run success, Exit code 138 is forced termination


Q2: Why use multi-stage Dockerfile builds? Give one concrete benefit beyond "smaller image".
A2: Use multi-stage build to save volumne and improve sercurity

Q3: Difference between docker compose down and docker compose stop. Which one removes named volumes?
A3: Docker compose stop is exit but not remove, docker compose down is remove. Docker compose down will remove named volumns

Q4: Container A in your Compose stack cannot reach container B by hostname b. Three things you check, in order.
1. Check if both containers are on the same network. Can check on file docker-compose.yaml
3. Check the exact hostname or service name before connecting
2. Check container B's status and application port binding


Q5: In AWS, what is the difference between an Internet Gateway and a NAT Gateway? Which one allows a private-subnet EC2 to reach the internet?
A5: Internet Gateway allows two-way public traffic, while a NAT Gateway allows only one-way outbound traffic. NAT Gateway is the component that allows an EC2 instance in a private subnet to reach the internet


Q6: Why should you almost never create a Pod directly in production? What does a Deployment give you that a bare Pod does not?
A6: Pods have no self-healing cpabilities. A Deployment is a higher-level controller that manages Pods: Self-Healing and Resilience, Zero-Downtime Rollouts and Rollbacks,  Declarative Scaling

Q7: A Pod shows CrashLoopBackOff. The first three commands you run, in order, and one unique signal each one reveals.
A7:
kubectl logs <pod-name> --previous Application-level stack traces or initialization errors
kubectl describe pod <pod-name> The container Exit Code and Termination Reason
kubectl get events --sort-by='.metadata.creationTimestamp' Cluster-level infrastructure blockages


Q8: Pod is 0/1 READY but the container is running. Which probe is failing, what is K8s doing right now, and how is that different from a failing liveness probe?

A8: Because the readiness probe is failing, Kubernetes considers the container alive but not ready to accept traffic.Failing Readiness Probe Determines if the app is ready to handle traffic. Failing Liveness Probe Determines if the app is alive or deadlocked.


Q9: The four Service types. Which one for: internal database, public API in AWS, exposing a dev service from minikube?
A9:
Internal Database -> ClusterIP
Public API in AWS -> LoadBalancer
Exposing a Dev Service from Minikube -> NodePort

Q10: 
Deployment with replicas: 10. maxUnavailable: 25%, maxSurge: 25%. Maximum Pods alive during a rolling update? Minimum ready?
A10:
Maximum Pods Alive: 13 (10 + 10*0.25)
Minimum Ready: 8 (10 - 10* 0.25)

Q11: A new version is crashing 5 minutes after deploy. Exact commands to roll back. How does K8s know what to roll back to?
kubectl rollout undo deployment/<deployment-name>
Kubernetes knows exactly what to roll back to by preserving previous ReplicaSets as blueprints within the cluster.

Q12: Why is kubectl apply idempotent but kubectl create is not? When does the difference matter?
A12
kubectl apply compare and update the different deployment
kubectl create create resource if is not exists and display error if it exist


Q13: Difference between an Ingress resource and an Ingress controller. Can you have one without the other?
A13:The difference is that an Ingress resource is just a configuration file, while an Ingress controller is the actual software that executes that configuration.Cannot have a functional routing system with one without the other; they are completely useless on their own.

Q14: Kubernetes Secrets are NOT encrypted by default; they are only Base64 encoded.
A14: Pods do not have CPU resource requests defined in their Deployment configuration

Q15: HPA shows TARGETS: unknown/70%. Most likely cause? What command confirms it?
A15 kubectl get deployment <deployment-name> -o yaml

Q16: HPA vs Cluster Autoscaler. One failure mode each one solves and the other cannot.
A16: HPA scales Pods based on application metrics, while Cluster Autoscaler (CA) scales Virtual Machines (Nodes) based on infrastructure resource availability

Q17: Compose service A talks to B by hostname b. K8s hostname for A → B in same namespace? In different namespace?
A17:
If both Service A and Service B are in the same namespace. b.default.svc.cluster.local
If Service A is in namespace-a and Service B is in namespace-b, you must explicitly include the target namespace in the hostname: b.namespace-b.svc.cluster.local


Q18: You updated a ConfigMap with kubectl apply. Pod still has old value. Exact command to fix it.
A18: kubectl rollout restart deployment/<deployment-name>

Q19: A Pod is in CreateContainerConfigError. Most likely cause? First command to confirm?
A19: Pod try to reference a ConfigMap or a Secret but they are not exist for can not find name inside yaml
kubectl describe pod <pod-name>


Q20: Difference between a Helm chart, a Helm release, and a Helm repository.
A20: a Helm Chart is the source code, a Helm Repository is the app store, and a Helm Release is the running application

Q21: After helm install my-redis bitnami/redis, how do you find the hostname your application uses to connect?
A21: Look at the Kubernetes Services created by the Helm release
kubectl get svc -l app.kubernetes.io/instance=my-redis

Q22: Does helm rollback rewrite history or create a new revision? What does helm history show after?
A22: helm rollback never rewrites history; it always creates a brand-new revision.

Q23: Why does Redis (or Postgres) use a StatefulSet rather than a Deployment? What does StatefulSet give you?
A23: Redis and Postgres use a StatefulSet rather than a Deployment because they are stateful databases that care deeply about identity, fixed storage association, and order
StatefulSet protects the data

Q24: Day 16 — full EKS lifecycle. Three resources you must verify are gone after eksctl delete cluster to confirm zero orphans.
A24:  Load Balancers, EBS Volumes, Security Groups 

Q25: tail -f vs tail -F. Which one breaks first in production and why?
A25: tail -f breaks first in production. Because it tracks the file by its internal file descriptor

Q26: A bash script works in your shell but fails when run via cron. Two most common causes? How do you simulate cron's environment locally?
A26: The two most common causes are missing environment variables (especially PATH) and incorrect working directory assumptions. To replicate cron's exact minimal environment for debugging, run your script using env -i. It will remove all Environment and Path

Q27: Why is --dry-run non-negotiable for any production-changing script? What's the implementation pattern that makes it reliable?
A27:  It verifies the exact blast radius and catches logical errors before any destructive changes hit production

Q28: What is terraform.tfstate? What happens to your infrastructure management if you delete it?
A28: terraform.tfstate is a JSON file mapping the declarative code to the real-world resources currently deployed in  cloud provider. If you delete the state file, actual cloud infrastructure keeps running perfectly healthy, but Terraform completely loses memory of it.

Q29: Terraform vs Ansible: which tool to create an EC2 instance, which to install nginx on it, why split there?
A29: Terraform to create the EC2 instance and Ansible to install Nginx. The split between these two tools is based on the separation of Orchestration (Provisioning) and Configuration Management

Q30: Three files always in .gitignore for a Terraform project. Why each one must not be committed.
A30: The three files that must always be included in .gitignore for a Terraform project are .terraform/, *.tfstate, and *.tfvars (or terraform.tfvars).