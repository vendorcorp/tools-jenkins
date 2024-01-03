################################################################################
# Load Vendor Corp Shared Infra
################################################################################
module "shared" {
  source      = "git::ssh://git@github.com/vendorcorp/terraform-shared-infrastructure.git?ref=v0.6.1"
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

################################################################################
# k8s Namespace
################################################################################
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins-operator"
  }
}

################################################################################
# Deploy jenkins operator
################################################################################
resource "helm_release" "jenkins_operator" {
  name       = "jenkins-operator"
  repository = "https://raw.githubusercontent.com/jenkinsci/kubernetes-operator/master/chart"
  chart      = "jenkins-operator"
  version    = "v0.8.0"
  namespace  = "jenkins-operator"

  # See https://jenkinsci.github.io/kubernetes-operator/docs/getting-started/latest/installing-the-operator/#configuring-operator-deployment
  values = [
    "${file("values/jenkins.yaml")}"
  ]
}