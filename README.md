# AWS Disaster Recovery with Terraform, Kubernetes, and EKS

This project demonstrates a robust disaster recovery (DR) architecture using AWS services, Terraform, Kubernetes, and EKS. It includes a multi-region setup with failover capabilities, ensuring high availability and resilience for applications.

---

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Configure AWS Credentials](#2-configure-aws-credentials)
  - [3. Initialize Terraform](#3-initialize-terraform)
  - [4. Deploy the Infrastructure](#4-deploy-the-infrastructure)
  - [5. Deploy Kubernetes Resources](#5-deploy-kubernetes-resources)
- [Failover Process](#failover-process)
- [Scripts](#scripts)
- [Monitoring and Alerts](#monitoring-and-alerts)
- [Cleanup](#cleanup)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This project sets up a disaster recovery solution for a cloud-based application. It uses:
- **Primary Region**: `eu-west-2` (London)
- **Secondary Region**: `us-east-1` (N. Virginia)

The solution includes:
- Multi-region VPCs with peering
- EKS clusters in both regions
- RDS database with a read replica in the DR region
- Route 53 health checks and failover DNS
- Kubernetes deployments for frontend and backend services
- Automated failover using an AWS Lambda function

---

## Architecture

<img width="6955" height="4091" alt="Blank diagram" src="https://github.com/user-attachments/assets/aa00a08a-1411-49c6-85f3-e31f9bd34a56" />

### Key Components:
1. **Primary Region**:
   - EKS cluster for production workloads
   - RDS database (primary)
   - ALB for frontend and backend services
2. **Secondary Region**:
   - EKS cluster for disaster recovery
   - RDS read replica
   - ALB for failover workloads
3. **Route 53**:
   - Health checks for ALBs
   - Failover DNS configuration
4. **AWS Lambda**:
   - Promotes the RDS read replica during failover
   - Updates Secrets Manager with the new database endpoint
5. **Terraform**:
   - Infrastructure as Code (IaC) for AWS resources
6. **Kubernetes**:
   - Manages application deployments and services

---

## Features

- **Multi-Region Deployment**: Ensures high availability and disaster recovery.
- **Automated Failover**: Lambda function promotes the DR database and updates DNS.
- **Infrastructure as Code**: Terraform modules for repeatable and scalable deployments.
- **Monitoring and Alerts**: Route 53 health checks and SNS notifications.
- **Kubernetes Workloads**: Frontend and backend services deployed on EKS.

## Prerequisites

1. **AWS CLI**: Installed and configured with appropriate credentials.
2. **Terraform**: Version `1.5.0` or later.
3. **kubectl**: Installed and configured for EKS.
4. **Helm**: Installed for deploying Kubernetes resources.
5. **jq**: For JSON parsing in scripts.
6. **dig**: For DNS resolution checks.

---
## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/teejayade2244/AWS-Cloud-Disaster-Recovery-Manifest-Repo.git
cd AWS-Cloud-Disaster-Recovery-Manifest-Repo
```

### 2. Configure AWS Credentials

Make sure your AWS CLI is configured:

```bash
aws configure
```

### 3. Initialize Terraform

Navigate to the terraform directory and initialize:

```bash
cd terraform
terraform init
```

### 4. Deploy the Infrastructure

Apply the Terraform scripts to provision AWS resources:

```bash
terraform apply
```

> **Note**: Review and update variable values in `terraform/variables.tf` as needed.

### 5. Deploy Kubernetes Resources

After the infrastructure is ready, deploy your workloads:

```bash
# Configure kubectl for each EKS cluster (Primary & Secondary)
aws eks --region eu-west-2 update-kubeconfig --name <primary-eks-cluster>
aws eks --region us-east-1 update-kubeconfig --name <dr-eks-cluster>

# Apply Kubernetes manifests
kubectl apply -f kubernetes/manifests/
# Or deploy with Helm
helm install <release-name> kubernetes/helm/
```

---

## Failover Process

1. **Detection**: Route 53 health checks monitor ALB endpoints in both regions.
2. **Trigger**: If the primary region is unhealthy, Route 53 automatically switches DNS to the secondary region.
3. **Database Promotion**: AWS Lambda promotes the RDS read replica to a standalone primary.
4. **Secrets Update**: Lambda updates AWS Secrets Manager with the new database endpoint.
5. **Application Update**: Kubernetes applications in the DR region continue serving traffic with the promoted database.

---

## Scripts

- **failover.sh**: Manual trigger for failover testing.
- **healthcheck.sh**: Checks health status of endpoints.
- **cleanup.sh**: Removes deployed resources and cleans up AWS accounts.

> Scripts are located in the `scripts/` directory and may require executable permissions (`chmod +x <script>`).

---

## Monitoring and Alerts

- **Route 53 Health Checks**: Monitors ALB endpoints.
- **SNS Notifications**: Sends alerts on failover events.
- **CloudWatch Alarms**: Monitor AWS resource health and usage.

---

## Cleanup

To remove all deployed resources:

```bash
cd terraform
terraform destroy
```

Clean up Kubernetes resources:

```bash
kubectl delete -f kubernetes/manifests/
helm uninstall <release-name>
```

---

## Contributing

Contributions are welcome! Please submit issues and pull requests for improvements or bug fixes.

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Submit a pull request.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## References

- [AWS Disaster Recovery Documentation](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/welcome.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes EKS Setup](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)

---

*For questions or support, please open an issue in this repository.*

