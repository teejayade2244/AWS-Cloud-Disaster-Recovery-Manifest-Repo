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

![Architecture Diagram](<img width="6955" height="4091" alt="Blank diagram" src="https://github.com/user-attachments/assets/aa00a08a-1411-49c6-85f3-e31f9bd34a56" />)

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


