# EKS Cluster — Plain English Guide

> ⬅️ **Main Repository Documentation**: Return to the root [**AWS IaC README**](file:///c:/Users/csbis/Documents/MyDocs/Codes/IaC_AWS/README.md) for an overview of both EC2 and EKS modules.

This folder contains a set of instructions (written in a language called **Terraform**) that
builds a **Kubernetes cluster on Amazon Web Services (AWS)**.

You do not need to understand Kubernetes to use this. Think of it like this:

- **AWS** is the company that rents out computers over the internet.
- **Kubernetes** ("k8s") is software that runs your applications across a group of those
  computers and restarts them if they crash.
- **EKS** is Amazon's ready-made version of Kubernetes.
- **Terraform** is a tool that reads these files and clicks all the buttons in AWS for you,
  in the right order, every time the same way.

You will type about six commands. The rest is editing one settings file.

> ⏱️ **Time:** roughly 20–30 minutes of waiting, 15 minutes of typing.
> 💵 **Cost:** this creates real, billable AWS resources. See [What this costs](#what-this-costs).

---

## Table of contents

1. [What gets built](#what-gets-built)
2. [What you must have BEFORE you start](#what-you-must-have-before-you-start)
3. [Install the tools](#install-the-tools)
4. [Step 1 — Make your settings file](#step-1--make-your-settings-file)
5. [Step 2 — Fill in the settings](#step-2--fill-in-the-settings)
6. [Step 3 — Choose where the "memory file" lives](#step-3--choose-where-the-memory-file-lives)
7. [Step 4 — Build the cluster](#step-4--build-the-cluster)
8. [Step 5 — Connect to your cluster](#step-5--connect-to-your-cluster)
9. [Optional extras (add-ons)](#optional-extras-add-ons)
10. [Changing something later](#changing-something-later)
11. [Deleting everything](#deleting-everything)
12. [What this costs](#what-this-costs)
13. [When something goes wrong](#when-something-goes-wrong)
14. [Things you should know before using this at work](#things-you-should-know-before-using-this-at-work)
15. [Glossary](#glossary)
16. [File map](#file-map)

---

## What gets built

| What | In plain words |
| --- | --- |
| An EKS cluster | The "brain" that decides what runs where. Amazon runs it for you. |
| A managed node group | The actual computers (EC2 servers) your applications run on. |
| Two security groups | Firewalls: one around the brain, one around the worker computers. |
| IAM roles | Permission badges, so the cluster is allowed to create disks, servers, etc. |
| An OIDC provider | A trust bridge, so individual applications can get their own AWS permissions instead of sharing one big badge. |
| Subnet tags | Small labels stuck on your network so AWS load balancers can find it. |
| Encryption | Kubernetes secrets and the servers' hard drives are encrypted with keys you supply. |
| Control-plane logging | Cluster activity is written to CloudWatch (on by default). |
| Optional add-ons | Five useful pieces of extra software — all **off** by default. See [Optional extras](#optional-extras-add-ons). |

**One important naming rule:** whatever you put in `cluster_name`, the real cluster gets `-eks`
added to the end. If you write `cluster_name = "tf-example"`, the cluster in AWS is called
**`tf-example-eks`**. Remember this — you'll need the full name when connecting.

---

## What you must have BEFORE you start

This code does **not** build these for you. They must already exist in your AWS account.
If you don't have them, ask whoever manages your AWS account. Write each answer down —
you'll paste them into the settings file in Step 2.

| # | You need | Looks like | Notes |
| --- | --- | --- | --- |
| 1 | An AWS account and login credentials | — | With permission to create EKS clusters, EC2 servers, IAM roles and security groups. Admin-level access is easiest. |
| 2 | A **VPC** (a private network in AWS) | `vpc-0a1b2c3d4e5f` | |
| 3 | The VPC's **address range** | `172.35.0.0/19` | Ask for the "CIDR block". |
| 4 | **At least 2 subnets in different availability zones** for the cluster brain | `subnet-1111`, `subnet-2222` | Two is the minimum; the code refuses to run with fewer. |
| 5 | **Private subnets** for the worker computers | `subnet-1111`, ... | Usually the same ones as #4. These need a NAT gateway or VPC endpoints so servers can reach the internet to download software. |
| 6 | *(Optional)* **Public subnets** | `subnet-4444`, ... | Only needed if you want internet-facing load balancers. |
| 7 | *(Optional)* A **KMS key** for encrypting Kubernetes secrets | `arn:aws:kms:eu-central-1:123456789012:key/...` | An encryption key. Must be in the same region. Only needed if you leave `eks_secrets_encryption_enabled = true`, and your login needs `kms:CreateGrant` on it. |
| 8 | A **KMS key** for encrypting the servers' hard drives | `arn:aws:kms:...` | Can be the same key as #7. |
| 9 | *(Optional)* An **EC2 key pair** name | `my-keypair` | Only if you want to log into the worker computers directly. Leave it as `""` if not — **a name that doesn't exist will make the build fail.** |
| 10 | *(Optional)* An **S3 bucket** | `my-tfstate-bucket` | Only if you want to share this setup with teammates. See Step 3. |

> ⚠️ **Requirement #5 matters more than it looks.** Worker computers with no route to the
> internet (no NAT gateway and no VPC endpoints) will start up and then never join the
> cluster, with no obvious error message.

---

## Install the tools

Install these on your computer (or on a server inside AWS — see the warning in Step 4).

### 1. Terraform

Download from <https://developer.hashicorp.com/terraform/install> — version **1.6 or newer**.

Or on Windows, in PowerShell:

```powershell
winget install Hashicorp.Terraform
```

Check it worked:

```powershell
terraform version
```

### 2. The AWS command line tool

Download from <https://aws.amazon.com/cli/> — version **2**.

Or on Windows:

```powershell
winget install Amazon.AWSCLI
```

Then log in:

```powershell
aws configure
```

It asks four questions. Paste your Access Key ID and Secret Access Key, type your region
(for example `eu-central-1`), and press Enter on the last one.

Check it worked — this should print your account number:

```powershell
aws sts get-caller-identity
```

### 3. kubectl

The tool for talking to your cluster once it exists.
Download from <https://kubernetes.io/docs/tasks/tools/> or:

```powershell
winget install Kubernetes.kubectl
```

---

## Step 1 — Make your settings file

Everything you can change lives in one file. There's an example provided — **copy it, don't
edit the example directly**, so you always have a clean reference.

Open PowerShell in this folder and run:

```powershell
Copy-Item tf-example.tfvars my-cluster.tfvars
```

Now open `my-cluster.tfvars` in any text editor (Notepad works, VS Code is nicer).

> The `.tfvars` file will contain your account details. **Never commit it to a public git
> repository.** Add `*.tfvars` to your `.gitignore` — but keep `tf-example.tfvars` and
> `tf_config_example.tfvars`, which contain only fake values.

---

## Step 2 — Fill in the settings

Go through the file and replace the fake values with your real ones from the
[checklist above](#what-you-must-have-before-you-start). Lines starting with `#` are notes —
they're ignored, so you can leave them alone.

### The ones you must change

```hcl
aws_region            = "eu-central-1"          # your region
vpc_id                = "vpc-1234567890"        # item 2
vpc_cidr              = "172.35.0.0/19"         # item 3
ctr_subnet_ids        = ["subnet-1111111111", "subnet-2222222222"]   # item 4 (2 minimum)
private_ng_subnet_ids = ["subnet-1111111111", "subnet-2222222222"]   # item 5
public_subnet_ids     = ["subnet-4444444444"]                        # item 6, or []

cluster_name    = "my-cluster"                  # becomes "my-cluster-eks"
cluster_version = "1.33"                        # Kubernetes version
iam_role_name   = "my-cluster"                  # a prefix for permission badges

kms_key_id_ebs  = "arn:aws:kms:...:key/..."     # item 8

ssh_key_name    = ""                            # item 9 — leave empty if unsure
```

### The ones worth a thought

```hcl
cluster_endpoint_public_access = false   # see the big warning below
eks_cluster_logging_enabled    = true    # activity logging — costs a little, worth it

eks_secrets_encryption_enabled = true    # extra encryption of Kubernetes secrets — see below
kms_key_arn_eks = "arn:aws:kms:...:key/..."   # item 7, only when the line above is true

deploy_eks_nodegroup        = true       # false = brain only, no worker computers
node_group_name             = "my-cluster"
node_group_version          = "1.33"     # must NOT be newer than cluster_version
node_group_desired_capacity = 1          # how many servers to start with
node_group_min_capacity     = 1          # never go below this
node_group_max_capacity     = 3          # never go above this
instance_type               = ["m5.large"]   # size of each server
ami_type                    = "AL2023_x86_64_STANDARD"   # operating system
disk_size                   = 100        # hard drive size in GB, per server
```

**About `eks_secrets_encryption_enabled`.** AWS *always* encrypts the cluster's stored data
with a key it owns. This setting adds a second lock on top of Kubernetes secrets, using a key
**you** own — the thing auditors usually ask for. Two catches:

- Your AWS login needs `kms:CreateGrant` (and `kms:DescribeKey`) on that key, and the key's own
  policy has to allow it. Without that the build fails on `kms:CreateGrant` — see
  [When something goes wrong](#when-something-goes-wrong).
- You can turn it **on** for an existing cluster, but you cannot turn it **off** again: going
  from `true` back to `false` destroys and rebuilds the cluster. Decide before the first build.

Set it to `false` for a sandbox or if you don't have a key, and leave `kms_key_arn_eks` empty.

### 🚨 The single most important setting

```hcl
cluster_endpoint_public_access = false
```

`false` means **the cluster can only be reached from inside your AWS network.** That is the
safer, recommended setting — but it has a big practical consequence:

> If you leave this `false`, you must run Terraform **from a computer inside the VPC**
> (an EC2 server, a CI runner) or **connected to it by VPN/Direct Connect.** From your laptop
> at home it will start building, then hang and time out.

If you're just experimenting and your laptop is outside AWS, set it to `true`, finish your
experiment, and delete the cluster afterwards. **Do not leave a public endpoint on anything
real without also restricting who can reach it.**

### About the two `@` placeholders

In the firewall (security group) section you'll see odd-looking values:

```hcl
cidr_blocks        = ["@vpc_cidr"]
security_group_ids = ["@cluster_additional_sg"]
```

These are shortcuts. `@vpc_cidr` means "whatever I typed for `vpc_cidr` above", and
`@cluster_additional_sg` means "the cluster firewall this code creates". They exist because a
settings file can't normally refer to other settings. **The defaults are sensible — leave this
whole section alone unless you know what you're changing.**

---

## Step 3 — Choose where the "memory file" lives

Terraform keeps a file recording everything it built. It's called the **state file**, and it's
important: lose it and Terraform forgets your cluster exists.

You have two options, controlled by one line near the top of your `.tfvars`:

### Option A — On your computer (simplest, fine for testing)

```hcl
use_s3_backend = false
```

The state is saved as `terraform.tfstate` in this folder. **Back it up.** If you delete it, you
can no longer manage or cleanly delete your cluster. Not suitable for teams — two people
cannot share it.

Then in Step 4 you simply run `terraform init`.

### Option B — In an S3 bucket (for teams and anything real)

```hcl
use_s3_backend = true
```

The state is stored in AWS instead, where teammates can share it and it can't be lost with your
laptop. You also need to edit `tf_config_example.tfvars` with your bucket details:

```hcl
bucket  = "my-tfstate-bucket"                          # must already exist
key     = "dev/eu-central-1/eks/my-cluster.tfstate"    # a filename inside it
region  = "eu-central-1"
encrypt = true
```

> ⚠️ **Heads-up about `use_s3_backend`.** Setting this to `true` does **not** by itself switch
> anything on. Comments in the code say a helper script (`tf-init.ps1` / `tf-init.sh`) reads
> this flag — **but those scripts are not present in this folder.** So you have to do the
> switch by hand, which is two extra commands. It's covered in Step 4 below.

---

## Step 4 — Build the cluster

Open PowerShell **in this folder**. Run the commands in order.

> 🚨 Reminder: if `cluster_endpoint_public_access = false`, run these from inside your AWS
> network, not from your laptop.

### 4a. If you chose Option B (S3), do this first — otherwise skip to 4b

Create a small file that tells Terraform to use S3. In PowerShell:

```powershell
@"
terraform {
  backend "s3" {}
}
"@ | Out-File -Encoding utf8 backend_override.tf
```

Then initialise, pointing at your bucket settings:

```powershell
terraform init -backend-config=tf_config_example.tfvars
```

Skip 4b and go to 4c.

### 4b. If you chose Option A (local state)

```powershell
terraform init
```

**What this does:** downloads the AWS plugins Terraform needs. Takes a minute. You want to see
`Terraform has been successfully initialized!`. You only need to do this once.

### 4c. Check what will be built — this changes nothing

```powershell
terraform plan -var-file=my-cluster.tfvars
```

**What this does:** shows you a preview. Nothing is created. Read the last line:

```
Plan: 42 to add, 0 to change, 0 to destroy.
```

Green `+` lines are things it will create. If you see red `-` lines on a first run, stop and
ask someone — something is wrong. If you get an error, jump to
[When something goes wrong](#when-something-goes-wrong).

### 4d. Actually build it

```powershell
terraform apply -var-file=my-cluster.tfvars
```

**What this does:** shows the same preview, then asks:

```
Do you want to perform these actions?
  Enter a value:
```

Type **`yes`** and press Enter. (Only the word `yes` works — `y` won't do.)

Now wait. **This takes 15–25 minutes**, most of it on one line that says the cluster is still
creating. That's normal. Don't close the window.

When it finishes you'll see `Apply complete!` followed by a list of outputs — names, addresses
and IDs of what was built.

---

## Step 5 — Connect to your cluster

Tell `kubectl` how to find your new cluster. Remember the `-eks` suffix:

```powershell
aws eks update-kubeconfig --region eu-central-1 --name my-cluster-eks
```

Then check the worker computers have joined:

```powershell
kubectl get nodes
```

You should see something like:

```
NAME                                          STATUS   ROLES    AGE   VERSION
ip-172-35-1-23.eu-central-1.compute.internal  Ready    <none>   3m    v1.33.0
```

`Ready` means it worked. **Congratulations — you have a working Kubernetes cluster.**

If it says `No resources found`, wait two minutes and try again — nodes take a moment to
register. If they never appear, see [When something goes wrong](#when-something-goes-wrong).

---

## Optional extras (add-ons)

Five useful pieces of software can be installed automatically. **All are switched off by
default.** Turn one on by changing its `enable_` line to `true` in your `.tfvars`, then run
`terraform apply -var-file=my-cluster.tfvars` again.

| Setting | What it gives you | Recommendation |
| --- | --- | --- |
| `enable_lbc` | **Load Balancer Controller** — lets Kubernetes create AWS load balancers so the internet can reach your apps. | Turn on if you're serving web traffic. |
| `enable_ebs` | **EBS CSI Driver** — lets applications request permanent disk storage (databases etc.). | Turn on if anything needs to save data. |
| `enable_metrics_server` | **Metrics Server** — enables `kubectl top` and automatic scaling of applications. | Safe and useful. Turn on. |
| `enable_cluster_autoscaler` | **Cluster Autoscaler** — adds and removes worker computers automatically as demand changes, between your min and max. | Useful, but set `node_group_max_capacity` carefully — it controls your bill. |
| `enable_vpc_cni` | **VPC CNI** — cluster networking. | ⚠️ **Leave this `false`.** Amazon already installs this. Turning it on makes Terraform try to create something that exists, and the build fails. Only for people who know exactly why they need it. |

**Two things to know about add-ons:**

1. They need worker computers to run on. Enabling add-ons with `deploy_eks_nodegroup = false`
   means they wait forever and eventually fail.
2. Terraform must be able to reach the cluster over the network to install them — the same
   private-endpoint warning from Step 2 applies, and applies *harder* here.

**Pin the versions.** Each add-on has a `_chart_version` setting. If you leave it empty, you get
whatever the newest version is on the day you run it — which means an unrelated change months
later can silently upgrade your software. The example file already pins sensible versions.

---

## Changing something later

Edit `my-cluster.tfvars`, then:

```powershell
terraform plan -var-file=my-cluster.tfvars     # see what would change
terraform apply -var-file=my-cluster.tfvars    # do it
```

**Always read the plan before typing `yes`.** Look for red `-` or orange `~ forces replacement`
lines — those mean something gets destroyed and rebuilt, which for a node group means your
applications restart.

Safe, everyday changes:

- `node_group_desired_capacity` — more or fewer servers.
- `node_group_min_capacity` / `max_capacity` — the scaling limits.
- `enable_*` add-on switches.
- Firewall rules.

Changes that replace your worker computers (plan for downtime):

- `instance_type`, `ami_type`, `disk_size`, `ssh_key_name`.

Changes that need care:

- `cluster_version` — upgrade **one minor version at a time** (1.31 → 1.32 → 1.33, never
  1.31 → 1.33). Upgrade the cluster first, then set `node_group_version` to match and apply
  again. Check what versions AWS still supports before choosing.

Things you effectively cannot change afterwards:

- `cluster_name`, `vpc_id`, the KMS keys. Changing these destroys and rebuilds the whole
  cluster. Same for turning `eks_secrets_encryption_enabled` from `true` back to `false` —
  switching it on later is fine, switching it off is not.

**Note on scaling:** if you turned on the Cluster Autoscaler, it manages the number of servers
itself, and this code deliberately ignores your `node_group_desired_capacity` afterwards so the
two don't fight. Use `min` and `max` to set the boundaries instead.

---

## Deleting everything

To tear it all down and stop the charges:

```powershell
terraform destroy -var-file=my-cluster.tfvars
```

Type `yes`. Takes 10–15 minutes.

> ⚠️ **This is permanent.** Everything in the cluster is gone, including any data stored in it.
> There is no undo and no recycle bin.

**Before destroying,** delete any load balancers your applications created (via
`kubectl delete service`), otherwise they can be left behind as orphaned resources that keep
charging you.

**If you deleted the cluster manually in the AWS console** and Terraform now errors when it
tries to look at the add-ons, tell it to forget them:

```powershell
terraform state rm 'module.loadbalancer_controller'
```

(repeat for whichever add-on modules are stuck).

---

## What this costs

Rough figures for a small cluster in `eu-central-1`, as a sense of scale only — check the
[AWS pricing calculator](https://calculator.aws/) for real numbers in your region.

| Item | Roughly |
| --- | --- |
| The EKS cluster itself | **~$73/month**, charged whether or not anything runs on it |
| One `m5.large` worker computer | **~$70/month** |
| 100 GB disk per worker | **~$8/month** |
| Control-plane logging to CloudWatch | a few dollars, depending on activity |
| NAT gateway (if your network has one) | **~$32/month** plus data charges |
| Load balancers created by your apps | ~$16/month each |

So a one-server test cluster lands somewhere near **$150–200/month if left running.**
**Run `terraform destroy` when you're done experimenting.** The cluster charge continues even
if you scale the workers to zero.

---

## When something goes wrong

Terraform is generally safe: if it fails halfway, run `apply` again and it picks up where it
left off. It won't build duplicates.

| What you see | What it means | What to do |
| --- | --- | --- |
| `No valid credential sources found` | AWS doesn't know who you are. | Run `aws configure` again, then `aws sts get-caller-identity`. |
| `EKS requires control plane subnets in at least two availability zones` | You gave fewer than 2 subnets. | Add a second subnet to `ctr_subnet_ids`. |
| `InvalidKeyPair.NotFound` | The `ssh_key_name` doesn't exist. | Set `ssh_key_name = ""` or use a real key pair name. |
| Hangs, then `context deadline exceeded` / `dial tcp ... i/o timeout` while installing add-ons | Terraform can't reach the cluster over the network. | The private-endpoint problem. Run from inside the VPC, or set `cluster_endpoint_public_access = true` for testing. |
| `serviceaccounts "aws-node" already exists` | You set `enable_vpc_cni = true`. | Set it back to `false`. |
| `ResourceInUseException` on the access entry | You pointed `eks_admin_role_arn` at the same identity that's running Terraform. | That identity is *already* an admin automatically. Set `enable_eks_admin_access = false`, or point it at a different role. |
| `InvalidRequestException: User not authorized to perform kms:CreateGrant` | Secrets encryption is on, but your login can't create a grant on the KMS key in `kms_key_arn_eks`. | Get `kms:CreateGrant` + `kms:DescribeKey` on that key (in your IAM policy *and* the key policy), or set `eks_secrets_encryption_enabled = false`. |
| `AccessDeniedException` | Your AWS login lacks permissions. | Ask your AWS administrator. |
| Cluster builds, but `kubectl get nodes` stays empty | Workers can't reach the internet to download their software. | Check the private subnets have a NAT gateway or the required VPC endpoints. |
| Add-ons fail on the very first run | Terraform sometimes needs the cluster to exist before it can configure the connection to it. | Just run `terraform apply -var-file=my-cluster.tfvars` again. |
| `Error acquiring the state lock` | A previous run was interrupted. | Make sure nothing else is running, then follow the unlock instructions Terraform prints. |

**A useful habit:** when you're stuck, run `terraform plan -var-file=my-cluster.tfvars`. It
never changes anything, and it tells you what Terraform currently thinks the situation is.

---

## Things you should know before using this at work

This code works, but a few choices in it are deliberate trade-offs that a reviewer should look
at before it's used for anything important. Listing them here honestly rather than hiding them:

1. **The worker computers have broad AWS permissions.** The node role in
   `modules/eks/iam-node.tf` attaches `AmazonS3FullAccess` and `AmazonRoute53FullAccess`. In
   Kubernetes, *any* application running on a node can borrow the node's permissions — so any
   app on this cluster can read and write every S3 bucket and every DNS record in the account.
   The file's own comment flags this. For production, remove those two attachments and give
   individual applications their own scoped permissions using IRSA (the OIDC bridge this code
   already sets up).

2. **There's an example IAM role you probably don't want.** `modules/eks/iam-irsa-example.tf`
   creates a demonstration role named `<iam_role_name>-oidc` for a service account called
   `aws-test` that doesn't exist. It's a teaching example. Delete the file for a real
   deployment.

3. **The helper scripts referenced in the comments aren't here.** `backend.tf`,
   `tf-example.tfvars` and `tf_config_example.tfvars` all mention `tf-init.ps1` / `tf-init.sh`,
   which are meant to automate the S3-backend switch. They are not in this folder. Step 4a
   above is the manual replacement.

4. **Add-on versions default to "newest".** Every `*_chart_version` defaults to an empty
   string, meaning "whatever is latest today". Pin them per environment (the example file
   does) so an unrelated change doesn't silently upgrade your software.

5. **The Metrics Server runs with `--kubelet-insecure-tls`.** This skips a certificate check.
   It's the common workaround on EKS, but it is a genuine (if small) loosening of security.

6. **State file safety.** With `use_s3_backend = false` the state lives only on your machine
   and has no locking, so two people running Terraform at once will corrupt it. Use the S3
   backend for anything shared.

---

## Glossary

| Word | Plain meaning |
| --- | --- |
| **Terraform** | The tool that reads these files and builds things in AWS. |
| **Kubernetes / k8s** | Software that runs applications across a group of computers. |
| **EKS** | Amazon's managed Kubernetes service. |
| **Cluster** | The whole system: the brain plus the worker computers. |
| **Control plane** | The "brain". Amazon runs and maintains it for you. |
| **Node / worker node** | One computer that actually runs your applications. |
| **Node group** | A set of identical worker computers managed as one unit. |
| **Pod** | The smallest unit Kubernetes runs — usually one application. |
| **VPC** | Your own private network inside AWS. |
| **Subnet** | A slice of that network, living in one data centre. |
| **CIDR** | A way of writing an address range, e.g. `172.35.0.0/19`. |
| **Availability zone (AZ)** | A separate data centre. Using two means one can fail. |
| **Security group** | A firewall. Lists what traffic is allowed in and out. |
| **IAM** | AWS's permission system. |
| **IAM role** | A set of permissions something can borrow. |
| **KMS key** | An encryption key managed by AWS. |
| **IRSA** | "IAM Roles for Service Accounts" — lets one application get its own AWS permissions instead of sharing the node's. |
| **OIDC** | The trust mechanism that makes IRSA work. |
| **Helm / chart** | An installer for Kubernetes software. A chart is one installable package. |
| **State file** | Terraform's memory of what it has built. Don't lose it. |
| **Apply** | The command that actually makes changes. |
| **Plan** | The command that previews changes without making any. |
| **`.tfvars`** | Your settings file. |
| **ARN** | AWS's unique ID format for a resource, e.g. `arn:aws:iam::123456789012:role/x`. |

---

## File map

For the curious. You only ever need to edit the two files marked ✏️.

```
eks-cluster/
├── README.md                    ← this file
├── tf-example.tfvars            ← ✏️ copy this to make your settings file
├── tf_config_example.tfvars     ← ✏️ S3 bucket details (only if use_s3_backend = true)
│
├── main.tf                      wires everything together
├── variables.tf                 the full list of settings and their defaults
├── providers.tf                 which AWS/Kubernetes plugins are used
├── backend.tf                   where the state file is kept
├── outputs.tf                   the information printed when the build finishes
│
└── modules/
    ├── eks/                     the cluster itself
    │   ├── cluster.tf              the control plane ("brain")
    │   ├── node-group.tf           the worker computers
    │   ├── security-groups.tf      the firewalls
    │   ├── iam-cluster.tf          permissions for the control plane
    │   ├── iam-node.tf             permissions for the workers  ← see note 1 above
    │   ├── iam-irsa-example.tf     demo role                    ← see note 2 above
    │   ├── oidc.tf                 the IRSA trust bridge
    │   ├── access.tf               who is allowed to administer the cluster
    │   └── subnet-tags.tf          labels so load balancers can find the network
    │
    └── addons/                  the five optional extras
        ├── aws-load-balancer-controller/
        ├── aws-ebs-csi-driver/
        ├── aws-vpc-cni/
        ├── aws-metrics-server/
        └── aws-cluster-autoscaler/
```

---

## The whole thing on one page

```powershell
# once
winget install Hashicorp.Terraform
winget install Amazon.AWSCLI
winget install Kubernetes.kubectl
aws configure

# set up
Copy-Item tf-example.tfvars my-cluster.tfvars
notepad my-cluster.tfvars          # fill in your real values

# build
terraform init
terraform plan  -var-file=my-cluster.tfvars
terraform apply -var-file=my-cluster.tfvars      # type: yes   (~20 min)

# connect  (note the -eks on the end of the name!)
aws eks update-kubeconfig --region eu-central-1 --name my-cluster-eks
kubectl get nodes

# when you're finished, to stop the charges
terraform destroy -var-file=my-cluster.tfvars    # type: yes
```
