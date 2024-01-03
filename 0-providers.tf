################################################################################
# Load Vendor Corp Shared Infra
################################################################################
module "shared" {
  source      = "git::ssh://git@github.com/vendorcorp/terraform-shared-infrastructure.git?ref=v0.6.1"
  environment = var.environment
}

################################################################################
# Load Vendor Corp Private Infra
################################################################################
module "shared_private" {
  source      = "git::ssh://git@github.com/vendorcorp/terraform-shared-private-infrastructure.git?ref=v0.1.0"
  environment = var.environment
}

################################################################################
# Connect to our k8s Cluster
################################################################################
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = module.shared.eks_cluster_arn
}

################################################################################
# Helm Provider
################################################################################
provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = module.shared.eks_cluster_arn
  }
}