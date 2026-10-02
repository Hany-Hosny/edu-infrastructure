# Edu Infrastructure

Terraform configuration for the AWS side of the Edu Cloud/DevOps assessment. The [application repository](https://github.com/Hany-Hosny/edu-app) contains the React frontend, Express backend, Dockerfiles and application CI.

The aim is a small environment that demonstrates networking, IAM, containers and a managed database. It is an assessment setup, not a highly available production service.

## What is implemented

Terraform defines the network, EC2 Docker host, RDS database, ECR repositories, IAM roles and basic monitoring. EC2 bootstrap installs and starts Docker.

Provisioning and application deployment are separate here. EC2 bootstrap installs Docker but does not automatically deploy the application.

For the assessment demonstration, the frontend and backend images were built and pushed to ECR and then deployed manually to the provisioned EC2 instance. The running application was verified through the public HTTP endpoint and the backend health check.

## AWS architecture

| Component | Current configuration |
| --- | --- |
| Network | One VPC, one public subnet, two private database subnets in different Availability Zones |
| Internet access | Internet Gateway and a public-subnet route; no NAT Gateway |
| Application host | One public EC2 instance using Amazon Linux 2023 and Docker; default type `t3.micro` |
| Database | Private, Single-AZ RDS PostgreSQL; default `db.t3.micro`, 20 GB encrypted gp3 storage |
| Images | Separate frontend and backend ECR repositories with scan-on-push enabled |
| Credentials | RDS-managed master password stored in Secrets Manager |
| Administration | EC2 IAM instance profile with Systems Manager permissions; no inbound SSH rule |
| Monitoring | Two CloudWatch log groups, an EC2 CPU alarm and an SNS topic |

Public inbound traffic to EC2 is limited to HTTP on port `80`. RDS allows PostgreSQL on `5432` only from the EC2 security group. The backend port is not exposed publicly. Application routing must therefore be wired through the web server before deployment is usable.

The default region is `us-east-1`. Resource names use the project and environment variables, and the AWS provider applies project, environment and Terraform management tags.

## Terraform layout

All configuration is under `terraform/`:

| Files | Responsibility |
| --- | --- |
| `01_providers.tf` to `04_data.tf` | Provider requirements, inputs, naming, Availability Zones and AMI lookup |
| `05_network.tf`, `06_security.tf` | VPC, subnets, routes and security groups |
| `07_ecr.tf`, `08_iam.tf` | Image repositories, instance permissions and GitHub OIDC role |
| `09_rds.tf`, `10_ec2.tf` | Database and Docker host |
| `11_monitoring.tf`, `12_outputs.tf` | Logs, alarm, notifications and deployment outputs |

State is local: no remote backend is configured. Keep state, saved plans and private variable values out of Git and shared screenshots. Retain the state securely until the environment has been destroyed; losing it makes cleanup harder.

## Security decisions

- RDS is not publicly accessible. Its security group accepts database traffic only from the application instance's security group.
- EC2 root storage and RDS storage are encrypted. EC2 requires IMDSv2.
- RDS generates and manages the master password. The EC2 role can retrieve that specific secret; the bootstrap script does not retrieve it automatically.
- ECR push/pull permissions are scoped to the two repositories where the AWS API supports resource scoping. ECR authorization uses a wildcard resource.
- The GitHub OIDC trust is restricted to the configured application repository's `main` branch and the STS audience. The role grants ECR publishing and SSM command permissions for deployment without storing long-lived AWS keys in GitHub.
- No inbound SSH port or SSH key is configured. The instance role supports Systems Manager access; the operator still needs suitable AWS permissions and a managed instance that is online.

There are deliberate limits. HTTP is unencrypted, EC2 outbound traffic is unrestricted, and a separate least-privilege application database user is not provisioned. The deployed backend connects to RDS using PostgreSQL TLS through the `DB_SSL=true` runtime setting. This environment should hold demo data only.

## Provision the infrastructure

Requirements are Terraform `>= 1.5.0`, the AWS CLI and an authenticated AWS identity with permissions to create the resources in this configuration. The AWS provider constraint is `~> 6.0`.

Authenticate using your normal AWS CLI profile or SSO process. Check the target account locally before creating anything:

```bash
aws sts get-caller-identity
```

Do not copy that output into public evidence without hiding the account ID and identity details.

From this repository:

```bash
cd terraform
```

Review `02_variables.tf` before planning. In particular, check the region, project/environment names, subnet ranges, instance sizes, database settings and GitHub owner/repository. The GitHub values must match the app repository, not this infrastructure repository.

The alert email variable has a default recipient. Override it explicitly to avoid subscribing that address unintentionally. To provision without an email subscription:

```bash
export TF_VAR_alert_email=""
```

Alternatively, supply your own address privately. Keep the same variable values for later plans and cleanup.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
```

`init` installs the provider and initializes the working directory. The next two commands check formatting and configuration. Review the plan for unexpected changes, replacements or deletions before applying it:

```bash
terraform apply tfplan
```

EC2, RDS, storage, public IPv4 and other AWS resources may incur charges. Do not assume this configuration is free to run.

The outputs include the EC2 public IP/DNS, an HTTP application address, the RDS address and port, the managed-secret ARN, the ECR URLs and the GitHub role ARN. Treat these outputs as deployment inputs. ARNs and ECR URLs contain the AWS account ID and should be redacted in public screenshots.

## Application deployment and CI/CD

The application workflow currently runs backend tests, builds the frontend and builds both Docker images on pushes and pull requests to `main`.

For the assessment demonstration, the images were pushed to ECR and deployed manually to EC2. The EC2 host retrieves the RDS credentials from Secrets Manager at runtime, and the frontend and backend run on a shared Docker network.

Terraform also includes a GitHub OIDC role and permissions suitable for extending this into automatic ECR publishing and SSM deployment. Automatic CD on pushes to `main` is not currently enabled.

Before treating EC2 as a running application environment:

1. Verify the application's tests, frontend build and both Docker image builds.
2. Publish the images to ECR and select the exact image versions to deploy.
3. Supply backend RDS settings securely at runtime, including credentials from the managed secret. Do not bake them into images or Terraform user data.
4. Configure the container network and port mapping so HTTP port `80` serves the frontend and forwards API requests internally. The app's frontend image includes Nginx routes for `/api/` and `/health`, targeting `backend:5050`; that container name must resolve on the deployment network.
5. Build the frontend with the correct browser-reachable API base URL. The local Compose value points to `localhost` and is not a cloud deployment setting.
6. Start the containers, verify database connectivity and `/health`, then test adding a course and homework from the browser.

EC2 user data only installs Docker; it does not install a deployment manifest or start these containers. The application Compose file is for local development and starts its own PostgreSQL container, so it should not be used unchanged with RDS.

## Monitoring

Terraform creates separate frontend and backend CloudWatch log groups with seven-day retention and attaches the required CloudWatch permissions to the EC2 role. The deployed containers use Docker's `awslogs` logging driver to send application logs to these groups. Bootstrap itself does not start or configure the containers.

The CPU alarm uses average EC2 utilization above 80% for two consecutive five-minute periods. Alarm and recovery notifications go to SNS. If an email subscription is configured, its recipient must confirm it before receiving notifications.

There are no application-availability, memory, disk-space or RDS-specific alarms in this configuration. The application's `/health` endpoint is available for a future external health check, but Terraform does not configure one.

## Trade-offs

A single EC2 host keeps the deployment small and makes the container and networking work easy to inspect. It is also a single point of failure, with no automatic scaling or load balancer. The public IP is not reserved and may change after stop/start or replacement.

RDS keeps PostgreSQL off the application host, but it is Single-AZ to limit assessment cost. Two private subnets satisfy the subnet-group layout; they do not make this database Multi-AZ. Backup retention is one day. Deletion protection is disabled and the final snapshot is skipped on deletion.

ECR tags are mutable, and there is no image-retention lifecycle policy. Using commit-based tags is useful for delivery, but immutable tags or digest-pinned releases would make rollback more reliable.

For a production service, priorities would be HTTPS, restricted database credentials, completed deployment and rollback automation, verified log delivery, stronger backups/deletion protection and remote Terraform state with locking. Multi-AZ application/database capacity and a load balancer would depend on availability requirements and budget.

## Screenshots / Evidence

No sanitized evidence screenshots are included in this checkout yet. Code and resource definitions describe the setup; they do not prove a successful apply or deployment.

The assessment evidence should cover:

| Capture | What it should demonstrate |
| --- | --- |
| Terraform apply | Successful completion for the reviewed configuration, with sensitive outputs hidden |
| GitHub Actions | A successful run for the submitted commit and its test/build jobs; do not label it a deployment run unless CD is implemented |
| EC2 and RDS | Instance status and a private database, without account or sensitive connection details |
| ECR | Published frontend/backend image versions, once image publishing has been completed |
| CloudWatch | CPU alarm configuration; actual log events only after log forwarding has been connected |
| Running application | A course and homework saved and still visible after refreshing the page |

Before attaching captures, remove AWS account IDs, credentials, secret values, passwords, personal email addresses and sensitive browser/terminal content. Crop account menus and redact account-bearing ARNs or repository URLs. Never include `.env`, Terraform state or a revealed Secrets Manager value.

## Cleanup

Back up any data you need before cleanup. Destroying this configuration deletes the RDS database without a final snapshot. Create and verify a manual snapshot first if the data must be kept.

ECR repositories are not configured for forced deletion. If images have been pushed, intentionally remove those images before destroying the repositories; this permanently removes those image versions from ECR. Retain any versions you need elsewhere first.

From `terraform/`, using the same AWS account, region, state and variable values used to create the environment:

```bash
terraform plan -destroy
terraform destroy
```

Review the resources before confirming. Keep the local state until destruction finishes successfully. Afterwards, check for anything created outside Terraform, such as manual snapshots, and remove it separately only when it is no longer needed.
