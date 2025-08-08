module "primary_networking" {
  source = "./modules/aws-region-base/networking" 
  region              = var.primary_region
  vpc_cidr            = var.primary_vpc_cidr
  public_subnet_cidrs = var.primary_public_subnet_cidrs
  private_subnet_cidrs = var.primary_private_subnet_cidrs
  environment_tag     = "Production"
  providers = {
    aws = aws.primary
  }
}

module "secondary_networking" {
  source = "./modules/aws-region-base/networking" 
  region              = var.secondary_region
  vpc_cidr            = var.secondary_vpc_cidr
  public_subnet_cidrs = var.secondary_public_subnet_cidrs
  private_subnet_cidrs = var.secondary_private_subnet_cidrs
  environment_tag     = "DisasterRecovery"

  providers = {
    aws = aws.secondary
  }
}

# Call the EKS module for the primary region
module "primary_eks" {
  source = "./modules/aws-region-base/eks" # Path to your EKS module

  # Pass variables to the module
  region                = var.primary_region
  environment_tag       = "Production"
  vpc_id                = module.primary_networking.vpc_id
  private_subnet_ids    = module.primary_networking.private_subnet_ids
  public_subnet_ids     = module.primary_networking.public_subnet_ids
  cluster_name          = "${var.cluster_name_prefix}-${var.primary_region}"
  kubernetes_version    = var.kubernetes_version
  node_instance_type    = var.node_instance_type
  node_group_desired_size = var.node_group_desired_size # Can be overridden in dev.tfvars
  node_group_max_size   = var.node_group_max_size
  node_group_min_size   = var.node_group_min_size

  # Explicitly pass the primary providers to the module
  providers = {
    aws        = aws.primary
    kubernetes = kubernetes.primary 
    helm       = helm.primary      
    tls        = tls.primary
  }
}

# Call the EKS module for the secondary region
module "secondary_eks" {
  source = "./modules/aws-region-base/eks" # Path to your EKS module

  # Pass variables to the module
  region                = var.secondary_region
  environment_tag       = "DisasterRecovery"
  vpc_id                = module.secondary_networking.vpc_id
  private_subnet_ids    = module.secondary_networking.private_subnet_ids
  public_subnet_ids     = module.secondary_networking.public_subnet_ids
  cluster_name          = "${var.cluster_name_prefix}-${var.secondary_region}"
  kubernetes_version    = var.kubernetes_version
  node_instance_type    = var.node_instance_type
  # For warm standby, secondary region desired size might be lower
  node_group_desired_size = 0 # Scale to 0 for cost savings in standby
  node_group_max_size   = var.node_group_max_size
  node_group_min_size   = 0 # Allow scaling down to 0

  # Explicitly pass the secondary providers to the module
  providers = {
    aws        = aws.secondary
    kubernetes = kubernetes.secondary 
    helm       = helm.secondary      
    tls        = tls.secondary
  }
}

# --- Data Sources for Existing EKS Clusters ---
# These data sources read the details of the EKS clusters created by the modules.

# Primary EKS Cluster Data
data "aws_eks_cluster" "primary" {
  provider = aws.primary
  name     = module.primary_eks.cluster_name
  depends_on = [module.primary_eks]
}

# Primary EKS Cluster Auth Data
data "aws_eks_cluster_auth" "primary" {
  provider = aws.primary
  name     = module.primary_eks.cluster_name
  depends_on = [module.primary_eks]
}

# Secondary EKS Cluster Data
data "aws_eks_cluster" "secondary" {
  provider = aws.secondary
  name     = module.secondary_eks.cluster_name
  depends_on = [module.secondary_eks]
}

# Secondary EKS Cluster Auth Data
data "aws_eks_cluster_auth" "secondary" {
  provider = aws.secondary
  name     = module.secondary_eks.cluster_name
  depends_on = [module.secondary_eks]
}

# --- Dynamic Kubernetes Provider Configuration for Primary EKS ---
# This configures the 'kubernetes.primary' provider with actual EKS cluster details
# It depends on the primary EKS cluster being fully created and its data sources populated.
provider "kubernetes" {
  alias = "primary"
  host                   = data.aws_eks_cluster.primary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.primary.token
}

# --- Dynamic Kubernetes Provider Configuration for Secondary EKS ---
provider "kubernetes" {
  alias = "secondary"
  host                   = data.aws_eks_cluster.secondary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.secondary.token

}

# --- Dynamic Helm Provider Configuration for Primary EKS ---
provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = data.aws_eks_cluster.primary.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.primary.token
  }
}

# --- Dynamic Helm Provider Configuration for Secondary EKS ---
provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = data.aws_eks_cluster.secondary.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.secondary.token
  }
}
