# EC2 Virtual Servers — Beginner's Setup Guide

> ⬅️ **Main Repository Documentation**: Return to the root [**AWS IaC README**](file:///c:/Users/csbis/Documents/MyDocs/Codes/IaC_AWS/README.md) for an overview of both EC2 and EKS modules.

This repository contains automated instructions (written in a tool called **Terraform**) that build and manage **virtual computers in Amazon Web Services (AWS)**.

You do **not** need to be an AWS expert or software developer to use this. Think of it like this:

- **AWS (Amazon Web Services):** Amazon's massive cloud data centers where you can rent computer hardware over the internet.
- **EC2 (Elastic Compute Cloud):** Amazon's service that rents you a virtual computer (called an **instance**).
- **Terraform:** A free program that acts like your personal assistant. It reads the simple text settings file you create, logs into AWS, and automatically builds all the virtual computers, firewalls, and hard drives for you.

---

## ⏱️ Quick Summary

- ⏱️ **Time required:** ~15 minutes to set up, 2–3 minutes for Terraform to build everything.
- 💵 **Cost:** AWS charges for real resources created. See [What this costs & AWS billing](#what-this-costs--aws-billing).
- 🛠️ **What you will do:** Copy 1 settings file, fill in a few values, and run 4 simple commands in your terminal.

---

## 📋 Table of Contents

1. [What Gets Built](#what-gets-built)
2. [Step 0 — What You Need BEFORE You Start (AWS Web Console Guide)](#step-0--what-you-need-before-you-start-aws-web-console-guide)
3. [Step 1 — Install the Required Tools](#step-1--install-the-required-tools)
4. [Step 2 — Create Your Personal Settings File](#step-2--create-your-personal-settings-file)
5. [Step 3 — Fill In Your Settings (Plain-English Walkthrough)](#step-3--fill-in-your-settings-plain-english-walkthrough)
6. [Step 4 — Choose Where Terraform Keeps Its Memory File](#step-4--choose-where-terraform-keeps-its-memory-file)
7. [Step 5 — Build Your Virtual Servers](#step-5--build-your-virtual-servers)
8. [Step 6 — Log Into Your Virtual Servers](#step-6--log-into-your-virtual-servers)
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

When you run this code, Terraform creates the following items inside your AWS account:

| Item | What it is in plain English |
| --- | --- |
| **EC2 Virtual Server(s)** | The actual virtual computers (Linux or Windows). You can build 1 or dozens at the same time. |
| **Security Group** | A digital firewall protecting your servers. Controls which network traffic is allowed in and out. |
| **IAM Role & Profile** | A security badge attached to your servers so they can safely interact with other AWS services. |
| **Extra Data Disks (Optional)** | Additional virtual hard drives (EBS volumes) attached to whichever servers need extra storage space. |
| **Elastic IPs (Optional)** | Fixed, static public IP addresses that stay the same even if you turn a server off and back on. |

> 🏷️ **How your servers are named:**
> Every server is named using a combination of your project prefix (`name_prefix`) and the server's key or custom name. For example, if `name_prefix = "my-servers"` and your server key is `"app-01"`, the server will be tagged **`my-servers-app-01`** in the AWS Console.

---

## Step 0 — What You Need BEFORE You Start (AWS Web Console Guide)

Terraform puts your servers inside a **private virtual network** in your AWS account. This code does **not** create that network for you — it must already exist. 

Log into your **[AWS Management Console](https://console.aws.amazon.com/)** and locate these 3 details:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        YOUR AWS ACCOUNT                                │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │  VPC (Your Private Virtual Network)                           │   │
│   │  ID: vpc-0a1b2c3d4e5f67890                                     │   │
│   │                                                                │   │
│   │   ┌──────────────────────────┐    ┌──────────────────────────┐ │   │
│   │   │ Subnet A (Room / Floor 1)│    │ Subnet B (Room / Floor 2)│ │   │
│   │   │ ID: subnet-1111111111111 │    │ ID: subnet-2222222222222 │ │   │
│   │   │                          │    │                          │ │   │
│   │   │  🖥️ Server 1 (app-01)    │    │  🖥️ Server 2 (win-01)    │ │   │
│   │   └──────────────────────────┘    └──────────────────────────┘ │   │
│   └────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

### 1. Your AWS Credentials
- **Access Key ID** (starts with `AKIA...`)
- **Secret Access Key** (a long secret string)
- *How to get them:* Click your account name at the top right of AWS Console $\rightarrow$ **Security credentials** $\rightarrow$ **Create access key**. Save these somewhere safe.

### 2. Your VPC ID (Virtual Private Cloud)
- **Looks like:** `vpc-0a1b2c3d4e5f67890`
- *How to find it:* Type **VPC** in the top AWS search bar $\rightarrow$ click **Your VPCs**. Copy the ID of the VPC you want to use.

### 3. Your Subnet IDs (Network Rooms)
- **Looks like:** `subnet-11111111111111111`, `subnet-22222222222222222`
- *How to find it:* In the VPC dashboard, click **Subnets** on the left menu. Copy 1 or 2 subnet IDs where you want your servers to live.

### 4. (Optional) EC2 Key Pair
- **Looks like:** `my-ssh-key`
- *How to find it:* Type **EC2** in the search bar $\rightarrow$ click **Key Pairs** on the left menu. If you want to log in using traditional SSH (Linux) or retrieve Windows passwords, note the name here. *If you use AWS Session Manager (recommended), you don't need a Key Pair!*

---

## Step 1 — Install the Required Tools

You need 2 free tools installed on your computer.

### 1. Terraform (Version 1.6 or newer)
- **Windows (PowerShell):**
  ```powershell
  winget install Hashicorp.Terraform
  ```
- **Mac (Terminal with Homebrew):**
  ```bash
  brew install terraform
  ```
- Check it worked:
  ```powershell
  terraform version
  ```

### 2. AWS Command Line Interface (AWS CLI v2)
- **Windows (PowerShell):**
  ```powershell
  winget install Amazon.AWSCLI
  ```
- **Mac (Terminal with Homebrew):**
  ```bash
  brew install awscli
  ```
- Configure your AWS credentials:
  ```powershell
  aws configure
  ```
  It will ask 4 quick questions:
  1. `AWS Access Key ID`: Paste your key from Step 0.
  2. `AWS Secret Access Key`: Paste your secret key from Step 0.
  3. `Default region name`: Enter your AWS region (e.g., `us-east-1`, `eu-central-1`, `ap-south-1`).
  4. `Default output format`: Press **Enter** (leave blank).

- Check it worked (this prints your AWS account ID number):
  ```powershell
  aws sts get-caller-identity
  ```

### 3. (Optional but Recommended) AWS Session Manager Plugin
Allows you to securely connect to your servers directly from your computer or AWS browser console without needing open SSH/RDP ports or SSH keys.
- **Windows (PowerShell):**
  ```powershell
  winget install Amazon.SessionManagerPlugin
  ```

---

## Step 2 — Create Your Personal Settings File

All configuration options live in one file. Always make a copy of the example file so you never edit the original example directly.

Open PowerShell or terminal **in this folder** and run:

```powershell
Copy-Item tf-example.tfvars my-servers.tfvars
```

Now open `my-servers.tfvars` in any text editor (like Notepad, VS Code, or Notepad++).

> 🔒 **Security Notice:** `my-servers.tfvars` will contain your specific network and account details. Never publish `.tfvars` files to public GitHub repositories. (This repository includes `*.tfvars` in `.gitignore` to protect you).

---

## Step 3 — Fill In Your Settings (Plain-English Walkthrough)

Here is how to set up `my-servers.tfvars`.

### 1. Core Settings (Required)

```hcl
aws_region  = "eu-central-1"     # The AWS region where your servers will live
name_prefix = "my-servers"       # Prefix added to the name of every resource created
```

---

### 2. Network Settings (Required)

Paste the VPC ID and Subnet IDs you found in Step 0:

```hcl
vpc_id = "vpc-0a1b2c3d4e5f67890"  # Item 2 from Step 0

# (Optional) The address range of your VPC.
# Leave it as "" and Terraform will automatically look it up from AWS for you!
vpc_cidr = ""

# Item 3 from Step 0: Give each subnet a friendly nickname (key).
# Fill in only the ones you have - leave the rest empty.
subnet_ids = {
  "private-a" = "subnet-11111111111111111"
  "private-b" = "subnet-22222222222222222"
  "private-c" = ""
  "public-a"  = ""
  "public-b"  = ""
  "public-c"  = ""
}
```

An entry may be left empty (`""`), which is how the example file ships: a full
three-AZ private/public layout you fill in as you go. Only the subnets your
instances actually point at are looked up in AWS, so empty slots cost nothing.
If an instance does use a `subnet_key` whose value is empty, the plan stops and
names that instance. The keys are yours - add, rename or remove them freely.

---

### 3. Server Definitions (`instances`)

The `instances` section is where you tell Terraform which virtual computers to build.

#### Example Single Server Setup:
```hcl
instances = {
  "app-01" = {
    subnet_key    = "private-a"   # Uses the subnet nickname defined in subnet_ids above
    os            = "linux"       # "linux" or "windows"
    instance_type = "t3.micro"    # Computer size (CPU/Memory)
  }
}
```

#### Understanding Advanced Server Features:

Each server inside `instances` supports the following options:

| Setting | What it does | Default if left out |
| --- | --- | --- |
| `enable` | Set `true` to build, or `false` to skip without deleting your configuration text. | `true` |
| `count` | Number of identical servers to create in this group. | `1` |
| `name` | Custom name(s). Can be single (`"web"`) or comma-separated (`"web-01, web-02"`). | Uses group key (`"app-01"`) |
| `subnet_key` | Subnet nickname from your `subnet_ids` map above. | Required (unless `subnet_id` used) |
| `subnet_id` | A direct literal subnet ID (e.g. `"subnet-99999..."`) if not in `subnet_ids`. | None |
| `os` | Operating System: `"linux"` or `"windows"`. | `"linux"` |
| `instance_type` | Server size (CPU/RAM). Linux runs well on `t3.micro`. Windows needs `t3.medium` or larger. | `t3.micro` |
| `ami_id` | Specific Operating System image ID (e.g., `"ami-012345..."`). | Uses newest standard AWS image |
| `key_name` | Name of your AWS Key Pair for SSH/RDP passwords. | `""` (None) |
| `private_ip` | Specific private IP address (assigned to 1st server if `count > 1`). | Auto-assigned by AWS |
| `associate_public_ip_address` | Set `true` to assign a temporary public internet address. | `false` |
| `associate_eip` | Set `true` to allocate a fixed, permanent public Elastic IP. | `false` |
| `security_group_ids` | List of extra firewall IDs specific to this server (`["sg-123..."]`). | `[]` |
| `root_volume_size` | Main hard drive size in Gigabytes (GB). | `30` GB |
| `root_volume_type` | Disk type (`"gp3"`, `"gp2"`, `"io1"`, etc.). | `"gp3"` |
| `user_data` | Custom startup script that runs automatically on first boot. | None |
| `ebs_volumes` | List of extra attached data hard drives (see recipes below). | `[]` |
| `tags` | Custom labels attached to this server (e.g. `{ Role = "database" }`). | `{}` |

---

### 4. Global Fallbacks & Default Settings

If a server in `instances` doesn't specify a setting, it automatically inherits from these root default settings:

```hcl
instance_type               = "t3.micro" # Default size for Linux
key_name                    = ""         # Default SSH Key Pair
associate_public_ip_address = false      # Keeps servers private by default
monitoring                  = false      # Detailed 1-minute CloudWatch metrics
disable_api_termination     = false      # Set true to prevent accidental deletion
root_volume_size            = 30         # Default root disk size (GB)
root_volume_type            = "gp3"      # Modern, fast EBS disk type
root_volume_encrypted       = true       # Encrypt disk contents at rest
kms_key_id_ebs              = ""         # Use free AWS-managed encryption key
metadata_hop_limit          = 1          # Security setting for internal IMDS credentials
```

---

### 5. Firewall / Security Group Settings

Terraform automatically creates a shared security group (firewall) for your servers.

```hcl
create_security_group = true

# Incoming network rules (Ingress)
sg_ingress_rules = [
  {
    description = "Allow SSH from inside the VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["@vpc_cidr"]  # "@vpc_cidr" automatically inserts your VPC address range!
  },
  {
    description = "Allow all traffic between servers in this group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
]

# Outgoing network rules (Egress)
sg_egress_rules = [
  {
    description = "Allow all outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
]
```

> 💡 **The `@vpc_cidr` Placeholder:**
> Writing `"@vpc_cidr"` inside `cidr_blocks` tells Terraform to automatically look up and insert your VPC's address range. You don't have to hardcode subnet CIDR numbers!

#### Attaching Existing Firewalls (Optional):
If your organization already has security groups created by someone else:
```hcl
enable_additional_security_groups = true
additional_security_groups = [
  { name = "corp-vpn-access-sg" },                            # Looked up by name in your VPC
  { name = "monitoring-sg", id = "sg-0123456789abcdef0" }     # Looked up directly by ID
]
```

---

### 6. IAM Permissions & Remote Login (`enable_ssm`)

```hcl
create_instance_profile = true
iam_role_name           = "my-servers"
enable_ssm              = true   # ALWAYS keep this true! Enables AWS Session Manager.
enable_cloudwatch_agent = false  # Set true if you send logs to AWS CloudWatch
instance_policy_arns    = []     # Additional IAM policy ARNs if needed
```

---

### 7. Operating System Images (AMIs) & Pinning

An **AMI (Amazon Machine Image)** is the template disk used to install the operating system.

```hcl
ami_ids = {
  linux   = ""   # Leave "" to automatically use the newest Amazon Linux 2023
  windows = ""   # Leave "" to automatically use the newest Windows Server 2022
}
```

> ⚠️ **IMPORTANT — Image Pinning Warning:**
> Leaving `ami_ids` as `""` means Terraform will always check AWS for the newest image. Every few weeks, AWS releases an updated OS image. When that happens, running `terraform plan` will attempt to **destroy and rebuild your servers** to apply the new image!
> 
> To prevent unexpected replacements, once your server is created, fetch its AMI ID from the output or AWS Console (e.g. `ami-0123456789abcdef0`) and paste it into `ami_ids.linux` or `ami_ids.windows`.

---

## Step 4 — Choose Where Terraform Keeps Its Memory File

Terraform keeps a record of everything it builds in a file called the **state file**.

### Option A — Simple Local Storage (Recommended for absolute beginners / testing)
In `my-servers.tfvars`:
```hcl
use_s3_backend = false
```
The memory file is saved on your computer as `./terraform.tfstate`.

### Option B — Remote S3 Storage (Recommended for teams and production)
In `my-servers.tfvars`:
```hcl
use_s3_backend = true
```
1. Open `tf_config_example.tfvars` and add your S3 bucket name and state file path:
   ```hcl
   bucket  = "my-company-tfstate-bucket"
   key     = "ec2/my-servers.tfstate"
   region  = "eu-central-1"
   encrypt = true
   ```
2. Create a file named `backend_override.tf` in this folder containing:
   ```hcl
   terraform {
     backend "s3" {}
   }
   ```
3. Initialize Terraform with your config file:
   ```powershell
   terraform init -backend-config=tf_config_example.tfvars
   ```

---

## Step 5 — Build Your Virtual Servers

Open PowerShell or terminal in your project directory and run these 3 commands in order:

### Command 1: Prepare Terraform (Initialize)

```powershell
terraform init
```
*What it does:* Downloads the AWS provider plugin. Takes about 30–60 seconds. You should see `Terraform has been successfully initialized!`. You only need to run this once.

---

### Command 2: Preview the Plan (Safe Check)

```powershell
terraform plan -var-file=my-servers.tfvars
```
*What it does:* Shows you a detailed preview of everything Terraform is about to build in AWS **without making any actual changes**.
Look at the summary line at the bottom:
`Plan: 5 to add, 0 to change, 0 to destroy.`

---

### Command 3: Build the Servers (Apply)

```powershell
terraform apply -var-file=my-servers.tfvars
```
*What it does:* Asks for your final confirmation.
1. Review the preview list.
2. When prompted: `Enter a value:`, type **`yes`** and press **Enter**.
3. Wait 1 to 3 minutes while Terraform creates your resources in AWS.
4. When finished, you will see `Apply complete!` followed by a list of server IDs, IP addresses, and ready-to-use login commands!

---

## Step 6 — Log Into Your Virtual Servers

### Method 1: AWS Session Manager (Easiest & Most Secure — No SSH Keys Required)

Because `enable_ssm = true` is set, you don't need open SSH ports, passwords, or key files!

Terraform automatically prints ready-to-use connect commands when `apply` finishes:

```powershell
aws ssm start-session --region eu-central-1 --target i-0123456789abcdef0
```

Simply copy and paste that command into your PowerShell or terminal. You instantly get a command prompt inside your server!

> ⏱️ **Note:** Give new servers 1–2 minutes after launch for the SSM agent to register with AWS.

---

### Method 2: SSH Connection (Linux Servers)

Requires `key_name` set to a valid AWS Key Pair name, port 22 open in your security group, and network connectivity to the server.

```powershell
ssh -i /path/to/my-key.pem ec2-user@172.35.1.50
```
*(Use `ec2-user` for Amazon Linux, or `ubuntu` for Ubuntu servers).*

---

### Method 3: RDP / Remote Desktop (Windows Servers)

1. If you launched your Windows server with a `key_name`, retrieve its decrypted Administrator password by running:
   ```powershell
   aws ec2 get-password-data --region eu-central-1 --instance-id i-0123456789abcdef0 --priv-launch-key /path/to/my-key.pem
   ```
2. Open **Remote Desktop Connection** (`mstsc.exe`) on your computer.
3. Enter the private IP address of your Windows server (from `terraform output rdp_targets`).
4. Log in as `Administrator` using the retrieved password.

---

## Step 7 — Common Setup Examples (Recipes)

### Recipe A: Launching Multiple Linux Servers

To build 2 Linux servers named `app-01` and `app-02`:

```hcl
instances = {
  "web-fleet" = {
    enable        = true
    count         = 2
    name          = "app-01, app-02"
    subnet_key    = "private-a"
    os            = "linux"
    instance_type = "t3.micro"
  }
}
```

---

### Recipe B: Launching a Windows Server

```hcl
instances = {
  "win-server" = {
    subnet_key    = "private-b"
    os            = "windows"
    instance_type = "t3.medium" # Windows requires at least 2 GB RAM (t3.medium or larger)
  }
}
```

---

### Recipe C: Adding an Extra Hard Disk (EBS Storage Volume)

To attach a 100 GB extra data disk to a database server:

```hcl
instances = {
  "db-01" = {
    subnet_key = "private-a"
    ebs_volumes = [
      {
        device_name = "/dev/sdf"  # On Windows, use "xvdf"
        size        = 100         # Size in GB
        type        = "gp3"
      }
    ]
  }
}
```

> ℹ️ **Formatting New Disks:**
> AWS attaches the disk to the server hardware, but operating systems require you to format new disks before use.
> - **Linux:** Run `lsblk` to identify the disk (e.g. `/dev/nvme1n1`), format with `sudo mkfs -t xfs /dev/nvme1n1`, and mount it to a folder (e.g. `sudo mount /dev/nvme1n1 /data`).
> - **Windows:** Open **Disk Management** (`diskmgmt.msc`), initialize the disk, and assign a drive letter (e.g. `D:`).

---

### Recipe D: Assigning a Fixed Public IP (Elastic IP)

```hcl
instances = {
  "public-web" = {
    subnet_key                  = "public-a"
    associate_public_ip_address = true
    associate_eip               = true # Gives a static IP that never changes when restarted
  }
}
```

---

### Recipe E: First-Boot Startup Script (`user_data`)

To automatically install web servers or software when the server boots for the first time:

```hcl
instances = {
  "web-01" = {
    subnet_key = "private-a"
    user_data  = <<-EOT
      #!/bin/bash
      dnf install -y nginx
      systemctl enable --now nginx
    EOT
  }
}
```

---

## Step 8 — Making Changes Later

To modify server sizes, add disks, or change firewall rules:

1. Edit your `my-servers.tfvars` file.
2. Run `terraform plan -var-file=my-servers.tfvars` to preview the change.
3. Run `terraform apply -var-file=my-servers.tfvars` to apply it.

### What Happens When You Edit Settings?

| Change Made | What AWS Does | Data Loss Risk |
| --- | --- | --- |
| Changing `instance_type` (e.g. `t3.micro` $\rightarrow$ `t3.medium`) | Server stops for ~30 seconds, resizes, and restarts. | 🟢 No data lost |
| Growing an `ebs_volumes` size | Disk grows in place while server runs. | 🟢 No data lost |
| Updating Security Group / Firewall rules | Firewall updates immediately. | 🟢 No data lost |
| Changing `ami_id`, `subnet_id`, or `key_name` | **Destroys old server & builds a new one.** | ⚠️ **Root disk replaced!** |
| Renaming an instance key | **Destroys old server & builds a new one.** | ⚠️ **Root disk replaced!** |

> ⚠️ **Always check the plan!** Look for `# forces replacement` in red text before typing `yes`.

---

## Step 9 — Deleting Everything (Stopping AWS Charges)

When you no longer need your servers, delete all created resources to prevent recurring AWS charges:

```powershell
terraform destroy -var-file=my-servers.tfvars
```

1. Type **`yes`** when prompted.
2. Terraform will cleanly delete all EC2 instances, security groups, IAM roles, and Elastic IPs it created.

> 🔴 **WARNING:** `terraform destroy` is permanent! All data on the server root disks and attached EBS volumes will be deleted.

---

## What This Costs & AWS Billing

AWS charges based on resource usage. Here is an approximate cost guide (based on US/EU regions):

| AWS Resource | Estimated Cost | Notes |
| --- | --- | --- |
| **`t3.micro` Instance** | ~$8.00 / month | Free-tier eligible for new AWS accounts! |
| **`t3.medium` Instance** | ~$30.00 / month | Recommended minimum for Windows |
| **`m5.large` Instance** | ~$70.00 / month | Production-grade server |
| **EBS Storage (`gp3`)** | ~$0.08 per GB / month | 30 GB root disk = ~$2.40 / month |
| **Elastic IP (EIP)** | ~$3.60 per month | Billed per address while allocated |
| **AWS Session Manager** | **FREE** | No charge for standard usage |

> 💡 **Cost Saver Tip:**
> Stopping an instance pauses CPU/RAM charges, but AWS still charges a few cents per month for the attached EBS storage disks. Running `terraform destroy` removes all resources completely and stops all charges.

---

## Troubleshooting & Common Errors

| Error Message | Cause | Solution |
| --- | --- | --- |
| `No valid credential sources found` | AWS CLI is not logged in. | Run `aws configure` and re-enter your AWS Access/Secret Keys. |
| `InvalidKeyPair.NotFound` | The `key_name` specified doesn't exist in your AWS region. | Set `key_name = ""` in your `.tfvars` or create the key pair in AWS Console. |
| `InvalidSubnetID.NotFound` | Subnet ID is invalid or belongs to a different AWS region. | Double check your subnet ID in the AWS VPC Console. |
| `Subnet subnet-xxx belongs to VPC vpc-aaa, not vpc-bbb` | Your subnet doesn't belong to the `vpc_id` you specified. | Ensure `vpc_id` and `subnet_ids` belong to the same VPC network. |
| `Unsupported: requested configuration is currently not supported` | Selected instance type is unavailable in that specific subnet zone. | Change `instance_type` (e.g., from `t3.micro` to `t2.micro`) or pick another subnet. |
| `TargetNotConnected` when using Session Manager | Server cannot reach AWS SSM endpoints. | Ensure your subnet has internet/NAT access or VPC endpoints, and wait 2 minutes after launch. |
| `OperationNotPermitted ... may not be terminated` | Termination protection is enabled (`disable_api_termination = true`). | Set `disable_api_termination = false` in `.tfvars`, run `apply`, then run `destroy`. |

---

## Things You Should Know Before Using This at Work

1. **Standalone Instances (Pets vs. Cattle):** These servers are standalone `aws_instance` resources. If physical AWS hardware fails, the server remains stopped until restarted.
2. **Backups:** This repository builds servers, but does not automatically configure AWS Backup schedules. Add a backup plan for critical production data.
3. **IAM Scoping:** The generated IAM role is shared across all instances in this fleet. Keep `instance_policy_arns` minimal to adhere to security best practices.

---

## Glossary of Terms

| Term | Plain-English Definition |
| --- | --- |
| **Terraform** | An open-source automation tool that creates cloud infrastructure using code. |
| **EC2** | Elastic Compute Cloud — Amazon's virtual computer rental service. |
| **Instance** | A single virtual computer server. |
| **VPC** | Virtual Private Cloud — Your private isolated network inside AWS. |
| **Subnet** | A sub-section or room within your VPC network. |
| **Security Group** | A digital firewall filter controlling incoming and outgoing network traffic. |
| **AMI** | Amazon Machine Image — The operating system disk template (Linux/Windows). |
| **EBS Volume** | Elastic Block Store — A virtual hard drive attached to your server. |
| **Elastic IP (EIP)** | A static public IP address reserved for your server. |
| **IAM** | Identity and Access Management — AWS's user and permission management service. |
| **Session Manager** | AWS tool for securely accessing server command lines without open ports or SSH keys. |
| **State File** | Terraform's internal memory file recording everything created. |

---

## File Map

```
ec2/
├── README.md                    ← 📖 This setup guide
├── tf-example.tfvars            ← ✏️ Copy this to "my-servers.tfvars" to configure your setup
├── tf_config_example.tfvars     ← ✏️ Optional S3 remote memory state configuration
│
├── main.tf                      ← Connects your settings to the EC2 module
├── variables.tf                 ← Complete list of settings, validation rules, and defaults
├── providers.tf                 ← Configures AWS plugin and automatic resource tagging
├── backend.tf                   ← Defines where Terraform stores its state memory
├── outputs.tf                   ← Controls what IP addresses and commands are printed after launch
│
└── modules/
    └── ec2/                     ← Core engine folder (calculates logic, builds resources)
        ├── main.tf              ← Resolves instance naming, AMI lookups, and defaults
        ├── instances.tf         ← Constructs the EC2 virtual servers
        ├── security-group.tf    ← Constructs the firewall rules
        ├── iam.tf               ← Constructs the server security roles and profiles
        ├── storage.tf           ← Constructs and attaches extra hard drives (EBS)
        ├── eip.tf               ← Allocates static public Elastic IPs
        ├── network.tf           ← Checks and validates existing VPC and subnets
        ├── variables.tf         ← Module input parameters
        ├── outputs.tf           ← Module outputs handed back to root
        └── versions.tf          ← Minimum required Terraform and AWS provider versions
```

---

## One-Page Quick Reference

Run these commands in PowerShell or Terminal to set up and manage your servers:

```powershell
# 1. Install tools (once)
winget install Hashicorp.Terraform
winget install Amazon.AWSCLI
aws configure

# 2. Prepare your settings file
Copy-Item tf-example.tfvars my-servers.tfvars
notepad my-servers.tfvars   # Fill in your region, vpc_id, subnet_ids, and instances

# 3. Build your servers
terraform init
terraform plan  -var-file=my-servers.tfvars
terraform apply -var-file=my-servers.tfvars   # Type: yes

# 4. Connect to a server
aws ssm start-session --region eu-central-1 --target i-0123456789abcdef0

# 5. Delete everything when finished (stops AWS charges)
terraform destroy -var-file=my-servers.tfvars # Type: yes
```
