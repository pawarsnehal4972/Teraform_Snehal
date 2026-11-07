# Terraform Assignment – Flask + Express on AWS

**Student:** Snehal
**GitHub repository:** `https://github.com/<your-username>/Terraform_Snehal`  <!-- replace with your link -->

Deploys a **Flask backend** (port 5000) and an **Express frontend** (port 3000) on AWS with Terraform in three ways:

| Part | Folder | What it builds |
|------|--------|----------------|
| 1 | `part1-single-ec2/` | Both apps on **one EC2 instance** (user-data + systemd) |
| 2 | `part2-separate-ec2/` | Custom VPC, 2 subnets, security groups, **two EC2 instances** (one per app) |
| 3 | `part3-docker-ecs/` | **ECR** repos, Docker images, **VPC**, **ECS Fargate** services, **ALB** |
| – | `bootstrap-state/` | S3 bucket used as the **remote Terraform backend** |
| – | `app/` | Source code of both apps + Dockerfiles |

## Architecture

```
Part 1                       Part 2                                  Part 3
Internet                     Internet                                Internet
   |                            |        |                              |
 [EC2]                      [EC2 Express]--private IP-->[EC2 Flask]   [ALB :80]
 Express :3000                  :3000                      :5000        |  /api/* -> Flask TG   (default -> Express TG)
 Flask   :5000              (subnet B)                  (subnet A)   [ECS Fargate]   [ECS Fargate]
                                  custom VPC + IGW                    Express        Flask
                                                                   images pulled from ECR, VPC with 2 public subnets
```

The Express app serves a small page and proxies `/api/*` to Flask (`BACKEND_URL`), so
the browser only ever talks to the frontend. In Part 3 the ALB routes `/api/*` directly to Flask.

## Prerequisites

* AWS account + credentials configured (`aws configure`) with permissions for EC2, VPC, ECR, ECS, ELB, IAM, CloudWatch, S3
* Terraform **>= 1.10** (S3 native state locking via `use_lockfile`)
* Docker (Part 3 only), AWS CLI
* Default region used everywhere: `ap-south-1` (change with `-var aws_region=...`)

> Cost note: everything is small (t3.micro, 0.25 vCPU Fargate tasks) but the ALB and Fargate tasks
> are billed hourly. Run `terraform destroy` when you finish and have taken your screenshots.

## Step 0 – Remote state bucket (one time)

```bash
cd bootstrap-state
terraform init
terraform apply
terraform output backend_hcl        # copy this block
```

Create `backend.hcl` (copy of `backend.hcl.example`) in each of `part1-single-ec2`, `part2-separate-ec2`, `part3-docker-ecs`
and paste the bucket name from the output. Each part stores its state under its own key in the same bucket.

## Part 1 – Single EC2

```bash
cd part1-single-ec2
terraform init -backend-config=backend.hcl
terraform fmt && terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Wait ~2–3 minutes for user-data to finish, then open:

* Flask:   `http://<public_ip>:5000/api/message`
* Express: `http://<public_ip>:3000`

Debug: EC2 console → Instance → Actions → Monitor and troubleshoot → *Get system log*
(or `/var/log/user-data.log` over SSH if you set `enable_ssh = true`, `allowed_ssh_cidr`, `key_name`).

```bash
terraform destroy      # when finished
```

## Part 2 – Separate EC2 instances

```bash
cd part2-separate-ec2
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

* Flask:   `http://<flask_public_ip>:5000/api/message`
* Express: `http://<express_public_ip>:3000`  (its "Backend status" box shows it reaching Flask over the **private IP**)

Security groups: both apps are open to the internet on their own port, and each security group also has a rule
that allows the other instance's security group (instance-to-instance traffic). SSH is disabled by default.

```bash
terraform destroy
```

## Part 3 – Docker, ECR, ECS, ALB

The ECR repositories must exist before images can be pushed, so apply in two phases:

```bash
cd part3-docker-ecs
terraform init -backend-config=backend.hcl
terraform validate

# Phase 1 – create only the ECR repositories
terraform apply -target=aws_ecr_repository.flask -target=aws_ecr_repository.express

# Build + push both images (linux/amd64) to ECR
./build_and_push.sh            # optional arg: image tag (default "latest")

# Phase 2 – everything else (VPC, ALB, ECS cluster and services)
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Open `terraform output express_url` (frontend) and `terraform output flask_api_url` (backend through the ALB).
Targets take 1–3 minutes to turn healthy. Check **ECS → Clusters → Services** and **EC2 → Target Groups**.

Optional local test before pushing: `cd app && docker compose up --build` → http://localhost:3000

```bash
terraform destroy        # deletes ALB, ECS, VPC and ECR (force_delete = true)
```

## Best practices followed

* `variables.tf` / `outputs.tf` in every part, no hard-coded values in resources
* Remote state in S3 (versioned, encrypted, public access blocked) with native locking
* Provider/Terraform version constraints and `default_tags`
* IMDSv2 required, encrypted gp3 root volumes, SSH closed by default
* ECS tasks only accept traffic from the ALB security group; logs go to CloudWatch
* Latest Amazon Linux 2023 AMI looked up with a data source

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| App not reachable right after apply | User-data still running; wait 2–3 min, check the system log |
| `terraform init` complains about `use_lockfile` | Upgrade Terraform to >= 1.10 |
| ECS tasks stop with `CannotPullContainerError` | Images not pushed yet (run `build_and_push.sh`) or built for ARM – script forces `linux/amd64` |
| Target group unhealthy | Check CloudWatch logs `/ecs/tf-assignment-part3/...` |
| Bucket name already exists | Change `bucket_prefix` in `bootstrap-state` |
