# AWS VPC Network — Beginner's Setup Guide

> ⬅️ **Main Repository Documentation**: Return to the root [**AWS IaC README**](file:///c:/Users/csbis/Documents/MyDocs/Codes/IaC_AWS/README.md) for an overview of the VPC, EC2 and EKS modules.

This folder contains automated instructions (written in a tool called **Terraform**) that build the **network** your servers and clusters live in.

You do **not** need to be an AWS expert to use this. Think of it like this:

- **VPC (Virtual Private Cloud):** Your own private slice of Amazon's network — like renting an empty office building.
- **Subnet:** One room in that building. A **public** room has a door to the street (the internet); a **private** room does not.
- **Internet Gateway:** The front door of the building.
- **NAT Gateway:** A one-way delivery hatch — machines in the private rooms can order things from the internet, but nobody outside can walk in.
- **Terraform:** A free program that reads your settings file, logs into AWS, and builds all of the above for you.

> 🧭 **Build this first.** The [`ec2/`](file:///c:/Users/csbis/Documents/MyDocs/Codes/IaC_AWS/ec2/README.md) and [`eks-cluster/`](file:///c:/Users/csbis/Documents/MyDocs/Codes/IaC_AWS/eks-cluster/README.md) configurations both expect a VPC and subnets to **already exist** — they only look them up. This one creates them and prints the exact IDs those two ask for.

---

## ⏱️ Quick Summary

- ⏱️ **Time required:** ~10 minutes to set up, 2–4 minutes for Terraform to build everything.
- 💵 **Cost:** The VPC, subnets, route tables and internet gateway are **free**. NAT gateways and interface endpoints are **not** — see [What This Costs](#what-this-costs--aws-billing).
- 🛠️ **What you will do:** Copy 1 settings file, choose your address ranges, and run 3 simple commands.

---

## 📋 Table of Contents

1. [What Gets Built](#what-gets-built)
2. [Step 0 — What You Need BEFORE You Start](#step-0--what-you-need-before-you-start)
3. [Step 1 — Install the Required Tools](#step-1--install-the-required-tools)
4. [Step 2 — Create Your Personal Settings File](#step-2--create-your-personal-settings-file)
5. [Step 3 — Fill In Your Settings (Plain-English Walkthrough)](#step-3--fill-in-your-settings-plain-english-walkthrough)
6. [Step 4 — Choose Where Terraform Keeps Its Memory File](#step-4--choose-where-terraform-keeps-its-memory-file)
7. [Step 5 — Build Your Network](#step-5--build-your-network)
8. [Step 6 — Handing the Network to `ec2/` and `eks-cluster/`](#step-6--handing-the-network-to-ec2-and-eks-cluster)
9. [Step 7 — Common Setup Examples (Recipes)](#step-7--common-setup-examples-recipes)
10. [Step 8 — Making Changes Later](#step-8--making-changes-later)
11. [Step 9 — Deleting Everything (Stopping AWS Charges)](#step-9--deleting-everything-stopping-aws-charges)
12. [What This Costs & AWS Billing](#what-this-costs--aws-billing)
13. [Troubleshooting & Common Errors](#troubleshooting--common-errors)
14. [Things You Should Know Before Using This at Work](#things-you-should-know-before-using-this-at-work)
15. [Glossary of Terms](#glossary-of-terms)
16. [File Map](#file-map)
17. [One-Page Quick Reference](#one-page-quick-reference)

---

## What Gets Built

With the settings file as shipped (`tf-example.tfvars`), Terraform creates:

| Item | How many | What it is in plain English |
| --- | --- | --- |
| **VPC** | 1 | Your private network, `172.32.0.0/16` — 65 536 addresses. |
| **Subnets** | 9 | Three tiers × three availability zones: `pvt` (apps), `ctr` (EKS control plane), `pub` (load balancers). |
| **Internet Gateway** | 1 | The front door, used by the public subnets. |
| **NAT Gateway + Elastic IP** | 1 | Lets the private subnets reach the internet outbound only. |
| **Route Tables** | 4 | One shared by the public subnets, one per availability zone for the private ones. |
| **S3 Gateway Endpoint** | 1 | A free shortcut to S3 that skips the NAT gateway (and its data charges). |
| **Interface Endpoints** | 0 | Off by default. Switch on `ssm`/`secretsmanager`/… when private subnets must reach an AWS API without a NAT gateway. |

```
                          Internet
                             │
                    ┌────────┴────────┐
                    │ Internet Gateway│
                    └────────┬────────┘
             ┌───────────────┼───────────────┐
        pub-1a           pub-1b           pub-1c        ← public tier (route: 0.0.0.0/0 → IGW)
        [NAT GW]                                        ← nat_gateway_mode = "single"
             │
     ┌───────┴───────┬───────────────┬───────────────┐
  pvt-1a / ctr-1a  pvt-1b / ctr-1b  pvt-1c / ctr-1c   ← private tiers (route: 0.0.0.0/0 → NAT GW)
```

> 🏷️ **How things are named:**
> Everything is named from your `name_prefix`. With `name_prefix = "tf-example"` you get the VPC **`tf-example-vpc`**, subnets **`tf-example-pvt-1a`**, **`tf-example-ctr-1b`**, **`tf-example-pub-1c`**, the gateways **`tf-example-igw`** and **`tf-example-nat-1a`**, and route tables **`tf-example-public`** / **`tf-example-private-1a`**.

---

## Step 0 — What You Need BEFORE You Start

Unlike the other two folders, this one needs **almost nothing to exist first** — that is the point of it.

### 1. Your AWS Credentials
An access key with permission to create VPC resources. Run `aws configure` (see [Step 1](#step-1--install-the-required-tools)), then check it works:

```powershell
aws sts get-caller-identity
```

### 2. A Region and Its Availability Zones
Pick the region you want to build in, then list its zones — you will paste these names into the settings file:

```powershell
aws ec2 describe-availability-zones --region eu-central-1 --query "AvailabilityZones[].ZoneName" --output text
```
> Output looks like `eu-central-1a  eu-central-1b  eu-central-1c`.

### 3. An Address Range That Does Not Clash
Pick a private range (`10.x`, `172.16–31.x`, `192.168.x`) that no other network in your company already uses. If you ever want to connect this VPC to another one — or to an office over VPN — two networks with the same range cannot talk to each other, and the range **cannot be changed later without deleting the VPC**.

---

## Step 1 — Install the Required Tools

### 1. Terraform (Version 1.6 or newer)

| Platform | Command |
| --- | --- |
| Windows | `winget install Hashicorp.Terraform` |
| macOS | `brew install terraform` |

Check it: `terraform version`

### 2. AWS Command Line Interface (AWS CLI v2)

| Platform | Command |
| --- | --- |
| Windows | `winget install Amazon.AWSCLI` |
| macOS | `brew install awscli` |

Then log in:

```powershell
aws configure
```
You will be asked for your **Access Key ID**, **Secret Access Key**, **Default region** (e.g. `eu-central-1`) and **Default output format** (`json`).

---

## Step 2 — Create Your Personal Settings File

Never edit the example file directly — copy it, so a later `git pull` cannot overwrite your values:

```powershell
copy tf-example.tfvars my-network.tfvars
```
```bash
cp tf-example.tfvars my-network.tfvars
```

Open `my-network.tfvars` in any text editor. Every setting is explained in the file itself, and in plain English below.

---

## Step 3 — Fill In Your Settings (Plain-English Walkthrough)

### 1. Core Settings (Required)

```hcl
aws_region  = "eu-central-1"   # Where to build. Must match the AZ names below.
name_prefix = "my-company"     # Goes in front of every resource name.

default_tags = {               # Stamped on everything, for cost reports.
  Environment = "dev"
  Owner       = "platform-team"
}
```

### 2. The VPC Itself

```hcl
vpc_cidr             = "172.32.0.0/16"  # 65,536 addresses. Cannot be changed later!
enable_dns_support   = true             # Leave on. EKS refuses to start without it.
enable_dns_hostnames = true             # Leave on. Needed by the interface endpoints.
```

> 📏 **How big should the VPC be?**
> `/16` = 65 536 addresses (the usual choice), `/20` = 4 096, `/24` = 256. If you plan to run EKS, go large: with the AWS VPC CNI **every pod takes a real VPC address**, so a small VPC runs out of room long before it runs out of CPU.

### 3. The Subnets (`subnet_groups`)

This is the heart of the file. A **group** is one tier of the network, spread over availability zones:

```hcl
subnet_groups = {
  "pvt" = {
    enable          = true
    tier            = "private"       # No route to the internet except through NAT.
    kubernetes_role = "internal-elb"  # Where internal load balancers may go.

    cidrs = {
      "eu-central-1a" = "172.32.0.0/20"
      "eu-central-1b" = "172.32.16.0/20"
      "eu-central-1c" = "172.32.32.0/20"
    }
  }

  "pub" = {
    tier            = "public"        # Route to the internet gateway.
    kubernetes_role = "elb"           # Where internet-facing load balancers may go.

    cidrs = {
      "eu-central-1a" = "172.32.96.0/20"
      "eu-central-1b" = "172.32.112.0/20"
      "eu-central-1c" = "172.32.128.0/20"
    }
  }
}
```

| Setting | What it means |
| --- | --- |
| `enable` | `false` deletes the whole group but keeps it in the file as a reminder. |
| `tier` | `"public"` → routed to the internet gateway. `"private"` → routed to a NAT gateway, if you asked for one. |
| `name` | Optional. Changes the middle part of the Name tag; defaults to the group's key. |
| `cidrs` | Availability zone → address range. **Leave a range as `""` to skip that zone.** |
| `map_public_ip_on_launch` | Optional. Defaults to `true` on public tiers, `false` on private ones. |
| `kubernetes_role` | Adds the tag the AWS Load Balancer Controller looks for (`elb` or `internal-elb`). |
| `kubernetes_clusters` | Cluster names to tag with `kubernetes.io/cluster/<name> = shared`. |
| `tags` | Extra tags for every subnet in the group. |

> ⚠️ **The group name is an identity, not a label.** Renaming `"pvt"` to `"private"` tells Terraform to **delete and recreate** those subnets — which fails while anything is still using them. Pick names once.

> 🧮 **Carving up a `/16` into `/20`s:** each `/20` holds 4 096 addresses, and the blocks run `x.x.0.0`, `x.x.16.0`, `x.x.32.0`, `x.x.48.0`, `x.x.64.0`, `x.x.80.0`, `x.x.96.0`, `x.x.112.0`, `x.x.128.0` … The example uses 9 of the 16 available and leaves the rest free.

### 4. Internet Access (the cost decision)

```hcl
create_internet_gateway = true
nat_gateway_mode        = "single"
```

| `nat_gateway_mode` | What you get | Roughly costs |
| --- | --- | --- |
| `"none"` | Private subnets have **no** internet access at all. Use with VPC endpoints only. | $0 |
| `"single"` | One NAT gateway shared by every zone. If that zone fails, all outbound traffic stops. | ~$33/month + data |
| `"one_per_az"` | One per zone, each private route table using its own. The production layout. | ~$33/month **each** + data |

### 5. VPC Endpoints (private routes to AWS services)

```hcl
gateway_endpoints   = ["s3"]   # Free. Keeps S3 traffic off the NAT gateway.
interface_endpoints = []       # Billed per hour + per GB. See below.
```

- **Gateway endpoints** (`s3`, `dynamodb`) are free and are wired into the private route tables. Leave `s3` on.
- **Interface endpoints** put a network card in your subnets so a private machine can reach an AWS API **without any NAT gateway**. The common set:

```hcl
interface_endpoints = ["ssm", "ssmmessages", "ec2messages"]  # Session Manager
```
  With those three, an EC2 instance from the [`ec2/`](file:///c:/Users/csbis/Documents/MyDocs/Codes/IaC_AWS/ec2/README.md) folder can be logged into with Session Manager even with `nat_gateway_mode = "none"`.

The endpoints get a security group of their own that allows **HTTPS (443) from `@vpc_cidr`** — the token `@vpc_cidr` simply means "the range of this VPC", so you do not have to type it twice:

```hcl
vpc_endpoint_ingress_cidrs = ["@vpc_cidr"]
```

---

## Step 4 — Choose Where Terraform Keeps Its Memory File

Terraform records everything it built in a **state file**. For a VPC this file matters more than usual: it is the longest-lived state you own, and every other configuration depends on the IDs inside it.

### Option A — Simple Local Storage (fine for testing)
In `my-network.tfvars`:
```hcl
use_s3_backend = false
```
The file is saved next to the code as `./terraform.tfstate`. **Do not commit it to git** and do not delete it — losing it means Terraform forgets it owns your network.

### Option B — Remote S3 Storage (recommended for teams and production)
In `my-network.tfvars`:
```hcl
use_s3_backend = true
```
1. Edit `tf_config_example.tfvars` with your bucket and path:
   ```hcl
   bucket  = "my-company-tfstate-bucket"
   key     = "Dev/eu-central-1/vpc/my-network.tfstate"
   region  = "eu-central-1"
   encrypt = true
   ```
2. Create a file named `backend_override.tf` in this folder containing:
   ```hcl
   terraform {
     backend "s3" {}
   }
   ```
3. Initialize with that config file:
   ```powershell
   terraform init -backend-config=tf_config_example.tfvars
   ```

---

## Step 5 — Build Your Network

### Command 1: Prepare Terraform (Initialize)
```powershell
terraform init
```
*Downloads the AWS provider plugin. Takes 30–60 seconds; only needed once.*

### Command 2: Preview the Plan (Safe Check)
```powershell
terraform plan -var-file=my-network.tfvars
```
*Shows exactly what will be created without touching AWS.* With the example file as shipped the summary reads `Plan: 31 to add, 0 to change, 0 to destroy.`

### Command 3: Build It (Apply)
```powershell
terraform apply -var-file=my-network.tfvars
```
Type **`yes`** when asked. The NAT gateway is the slow part — expect 2–4 minutes.

---

## Step 6 — Handing the Network to `ec2/` and `eks-cluster/`

When the apply finishes, the IDs the other two folders need are printed as outputs. You do not have to hunt for them in the console.

### For `eks-cluster/`
```powershell
terraform output eks_cluster_inputs
```
```
{
  "vpc_id"                = "vpc-0a1b2c3d4e5f67890"
  "vpc_cidr"              = "172.32.0.0/16"
  "ctr_subnet_ids"        = ["subnet-aaa...", "subnet-bbb...", "subnet-ccc..."]
  "private_ng_subnet_ids" = ["subnet-ddd...", "subnet-eee...", "subnet-fff..."]
  "public_subnet_ids"     = ["subnet-ggg...", "subnet-hhh...", "subnet-iii..."]
}
```
Paste those five values straight into `eks-cluster/my-cluster.tfvars`.

> This output reads the group names `ctr`, `pvt` and `pub`. If you renamed your groups, use `terraform output subnet_ids_by_group` and copy the lists by hand.

### For `ec2/`
```powershell
terraform output vpc_id
terraform output vpc_cidr
terraform output ec2_subnet_ids
```
`ec2_subnet_ids` comes out in exactly the shape the `ec2` folder's `subnet_ids` map wants:
```hcl
subnet_ids = {
  "pvt-1a" = "subnet-aaa..."
  "pvt-1b" = "subnet-bbb..."
  "pub-1a" = "subnet-ggg..."
}
```

### 🏷️ A note on the Kubernetes subnet tags
This configuration writes `kubernetes.io/role/elb` and `kubernetes.io/role/internal-elb` onto the subnets (from `kubernetes_role`), and `eks-cluster/modules/eks/subnet-tags.tf` writes the **same** tags onto the subnet IDs you hand it. Both write the same value, so they agree and neither fights the other on `apply`. If you would rather have the EKS configuration own those tags alone, set `kubernetes_role = ""` on your groups here.

---

## Step 7 — Common Setup Examples (Recipes)

### Recipe A: The cheapest possible development network
No NAT gateway at all — private subnets reach AWS APIs through endpoints and nothing else:
```hcl
nat_gateway_mode    = "none"
gateway_endpoints   = ["s3"]
interface_endpoints = ["ssm", "ssmmessages", "ec2messages"]
```

### Recipe B: Production, no single point of failure
```hcl
nat_gateway_mode = "one_per_az"
```
Each private route table then uses the NAT gateway in its **own** zone, so a zone outage takes down only that zone.

### Recipe C: Two availability zones instead of three
Leave the third range empty in every group — the entry stays as documentation and nothing else shifts:
```hcl
cidrs = {
  "eu-central-1a" = "172.32.0.0/20"
  "eu-central-1b" = "172.32.16.0/20"
  "eu-central-1c" = ""
}
```

### Recipe D: A private-only VPC (no internet at all)
```hcl
create_internet_gateway = false
nat_gateway_mode        = "none"
```
Then give every group `tier = "private"`.

### Recipe E: Adding a database tier later
Add a group; nothing that already exists is touched:
```hcl
"db" = {
  tier  = "private"
  cidrs = {
    "eu-central-1a" = "172.32.144.0/20"
    "eu-central-1b" = "172.32.160.0/20"
  }
  tags = { Tier = "database" }
}
```

---

## Step 8 — Making Changes Later

Edit `my-network.tfvars`, then run `terraform plan -var-file=my-network.tfvars` and read the summary before applying.

| Change | What happens |
| --- | --- |
| Add a group, or a zone inside a group | New subnets are added. Nothing existing is touched. ✅ |
| Set a group's `enable = false` | Those subnets are **destroyed**. Fails while anything still uses them. ⚠️ |
| Change a subnet's CIDR | That subnet is **destroyed and recreated**. ⚠️ |
| Rename a group's key | Destroy + recreate of its subnets. Use `name` instead to change the label only. ⚠️ |
| `single` → `one_per_az` | Extra NAT gateways added; the existing one stays where it is. ✅ |
| `one_per_az` → `single` | The extra gateways are deleted and the other zones re-routed through the survivor. ✅ |
| Change `vpc_cidr` | The **entire VPC** is replaced. Practically: build a new one. 🛑 |
| Add or remove an endpoint | Only that endpoint changes. ✅ |

---

## Step 9 — Deleting Everything (Stopping AWS Charges)

```powershell
terraform destroy -var-file=my-network.tfvars
```

> [!WARNING]
> A VPC cannot be deleted while **anything** still lives in it — instances, load balancers, EKS clusters, RDS databases, leftover network interfaces. Destroy in the reverse order you built: `eks-cluster/` and `ec2/` first, this folder last. If `destroy` hangs on the internet gateway or a subnet, something created outside Terraform (very often an ELB left behind by a Kubernetes Service) is still holding a network interface.

---

## What This Costs & AWS Billing

| Resource | Cost |
| --- | --- |
| VPC, subnets, route tables, security groups | **Free** |
| Internet gateway | **Free** (you pay only for data transfer out) |
| **NAT gateway** | ~**$0.045/hour (~$33/month) each** + ~$0.045 per GB processed |
| **Elastic IP** attached to a NAT gateway | Free while attached |
| **Gateway endpoint** (S3, DynamoDB) | **Free** — and it *saves* NAT data charges |
| **Interface endpoint** | ~**$0.01/hour per zone (~$7/month each)** + ~$0.01 per GB |

> 💡 Prices are approximate, vary by region, and change — check the AWS pricing pages. The practical rule: an idle network with `nat_gateway_mode = "none"` costs nothing, `"single"` costs about $33/month, `"one_per_az"` about $100/month.

---

## Troubleshooting & Common Errors

<details>
<summary><b>InvalidSubnet.Range: The CIDR is not within the VPC CIDR</b></summary>

A subnet range in `subnet_groups` sits outside `vpc_cidr`. Terraform checks that a subnet is not *larger* than the VPC, but it cannot check placement — `172.33.x.x` in a `172.32.0.0/16` VPC gets this error from AWS. Recheck the ranges against the `/20` list in [Step 3](#3-the-subnets-subnet_groups).
</details>

<details>
<summary><b>InvalidSubnet.Conflict: The CIDR overlaps with another subnet</b></summary>

Two groups were given overlapping ranges. Every range in the file must be distinct — an identical duplicate is caught at plan time, but a partial overlap (e.g. a `/20` inside a `/18`) is only caught by AWS.
</details>

<details>
<summary><b>"nat_gateway_mode = single needs a public subnet…"</b></summary>

A NAT gateway has to live in a public subnet. Either add a group with `tier = "public"`, or set `nat_gateway_mode = "none"`.
</details>

<details>
<summary><b>Instances in a private subnet cannot reach the internet</b></summary>

Check in order: `nat_gateway_mode` is not `"none"`; there is a public subnet with `create_internet_gateway = true`; and the instance really is in one of this configuration's subnets (a subnet with no route table association falls back to the VPC main route table, which this configuration deliberately never touches).
</details>

<details>
<summary><b>An interface endpoint resolves but every connection times out</b></summary>

Almost always the security group. This configuration creates one that allows 443 from `@vpc_cidr`; if you narrowed `vpc_endpoint_ingress_cidrs`, the calling subnet may no longer be in the list.
</details>

<details>
<summary><b>DuplicateSubnetsInSameZone on an endpoint</b></summary>

An interface endpoint may name at most one subnet per availability zone. That is why the ENIs are placed in **one group** (`interface_endpoint_subnet_group`, default: the first private group in alphabetical order) rather than in "all private subnets".
</details>

<details>
<summary><b>DependencyViolation on destroy</b></summary>

Something is still using the network. See [Step 9](#step-9--deleting-everything-stopping-aws-charges).
</details>

---

## Things You Should Know Before Using This at Work

- **The address range is forever.** Changing `vpc_cidr` replaces the VPC and everything in it. Agree the range with whoever owns your company's networks before the first apply.
- **`"single"` NAT is a single point of failure.** Fine for development, not for production traffic.
- **Use the S3 backend.** Everything else in this repository consumes IDs from this state; keeping it on one laptop is a real risk.
- **Flow logs are not created here.** If your environment requires network audit logging, add VPC flow logs separately.
- **Network ACLs are left at their AWS defaults** (allow all). Traffic control is expected to be done with security groups, as in the `ec2` and `eks-cluster` configurations.

---

## Glossary of Terms

| Term | Plain English |
| --- | --- |
| **VPC** | Your private network inside AWS. |
| **CIDR** | An address range written as `172.32.0.0/16`. The smaller the number after the slash, the bigger the range. |
| **Subnet** | A slice of the VPC that lives in exactly one availability zone. |
| **Availability Zone (AZ)** | A separate data centre within a region. Spreading over zones is how you survive one failing. |
| **Route table** | The list of "to reach X, go via Y" rules attached to a subnet. |
| **Internet Gateway (IGW)** | The VPC's door to the internet. Makes a subnet public. |
| **NAT Gateway** | Lets private machines start connections out to the internet; nothing can start one in. |
| **Elastic IP** | A fixed public address. Each NAT gateway gets one. |
| **VPC Endpoint** | A private path to an AWS service that does not go over the internet. |
| **Tier** | This configuration's word for one row of subnets with the same purpose (`pvt`, `ctr`, `pub`). |

---

## File Map

```
vpc/
├── README.md                      <-- (This Document)
├── main.tf                        <-- Root caller invoking ./modules/vpc
├── variables.tf                   <-- Input variable schemas, defaults and validation
├── outputs.tf                     <-- IDs, plus ready-made inputs for ec2/ and eks-cluster/
├── providers.tf                   <-- AWS provider configuration (~> 5.83) and default_tags
├── backend.tf                     <-- Local state by default; S3 via backend_override.tf
├── tf-example.tfvars              <-- Comprehensive example settings (copy this one)
├── tf_config_example.tfvars       <-- S3 backend settings, for `init -backend-config`
└── modules/
    └── vpc/                       <-- Internal VPC module logic
        ├── main.tf                <-- Subnet/NAT/endpoint layout computed from the variables
        ├── vpc.tf                 <-- aws_vpc + the plan-time checks for the whole config
        ├── subnets.tf             <-- aws_subnet, one per group × availability zone
        ├── igw.tf                 <-- Internet gateway
        ├── nat.tf                 <-- Elastic IPs and NAT gateways
        ├── routes.tf              <-- Route tables, default routes, associations
        ├── endpoints.tf           <-- Gateway and interface VPC endpoints
        ├── security-group.tf      <-- Security group for the interface endpoints
        ├── variables.tf           <-- Module input schema (mirrors the root)
        ├── outputs.tf             <-- Module outputs
        └── versions.tf            <-- Terraform and provider version constraints
```

---

## One-Page Quick Reference

```powershell
# 1. Install tools (once)
winget install Hashicorp.Terraform
winget install Amazon.AWSCLI
aws configure

# 2. Prepare your settings file
cd vpc
copy tf-example.tfvars my-network.tfvars
notepad my-network.tfvars      # region, name_prefix, vpc_cidr, subnet_groups, nat_gateway_mode

# 3. Build the network
terraform init
terraform plan  -var-file=my-network.tfvars
terraform apply -var-file=my-network.tfvars

# 4. Collect the IDs the other folders need
terraform output vpc_id
terraform output eks_cluster_inputs
terraform output ec2_subnet_ids

# 5. Delete everything when finished (destroy ec2/ and eks-cluster/ FIRST)
terraform destroy -var-file=my-network.tfvars
```
