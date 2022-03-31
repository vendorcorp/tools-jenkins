################################################################################
# Load Vendor Corp Shared Infra
################################################################################
module "shared" {
  source      = "git::ssh://git@github.com/vendorcorp/terraform-shared-infrastructure.git?ref=v0.3.0"
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
# k8s Namespace
################################################################################
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.target_namespace
  }
}

################################################################################
# Create PersistentVolume
#
# This is pinned to the first AVAILABLE REGION
################################################################################
resource "kubernetes_persistent_volume" "jenkins" {
  metadata {
    name = "jenkins-pv"
  }
  spec {
    capacity = {
      storage = "20Gi"
    }
    volume_mode                      = "Filesystem"
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"

    persistent_volume_source {
      host_path {
        path = "/data/jenkins-vol"
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "instancegroup"
            operator = "In"
            values   = ["shared"]
          }
        }
        node_selector_term {
          match_expressions {
            key      = "topology.kubernetes.io/zone"
            operator = "In"
            values   = [module.shared.availability_zones[0]]
          }
        }
      }
    }
  }
}

################################################################################
# k8s Service Account
################################################################################
resource "kubernetes_service_account" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

################################################################################
# k8s ClusterRole
################################################################################
resource "kubernetes_cluster_role" "jenkins" {
  metadata {
    name = "jenkins"
    annotations = {
      "rbac.authorization.kubernetes.io/autoupdate" = "true"
    }
    labels = {
      "kubernetes.io/bootstrapping" = "rbac-defaults"
    }
  }

  rule {
    api_groups = ["*"]
    resources = [
      "statefulsets",
      "services",
      "replicationcontrollers",
      "replicasets",
      "podtemplates",
      "podsecuritypolicies",
      "pods",
      "pods/log",
      "pods/exec",
      "podpreset",
      "poddisruptionbudget",
      "persistentvolumes",
      "persistentvolumeclaims",
      "jobs",
      "endpoints",
      "deployments",
      "deployments/scale",
      "daemonsets",
      "cronjobs",
      "configmaps",
      "namespaces",
      "events",
      "secrets",
    ]
    verbs = ["create", "get", "watch", "delete", "list", "patch", "udpate"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch", "update"]
  }
}

################################################################################
# k8s ClusterRoleBinding
################################################################################
resource "kubernetes_cluster_role_binding" "jenkins" {
  metadata {
    name = "jenkins"
    annotations = {
      "rbac.authorization.kubernetes.io/autoupdate" = true
    }
    labels = {
      "kubernetes.io/bootstrapping" = "rbac-defaults"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "jenkins"
  }

  subject {
    kind      = "Group"
    name      = "system:serviceaccounts:jenkins"
    api_group = "rbac.authorization.k8s.io"
  }
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
# Deploy aws-load-balancer-controller
################################################################################
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "3.11.8"
  namespace  = var.target_namespace

  # See https://github.com/jenkinsci/helm-charts/blob/main/charts/jenkins/VALUES_SUMMARY.md
  values = [
    "${file("values.yml")}"
  ]
  set {
    name  = "controller.jenkinsUrl"
    value = "https://jenkins.corp.${module.shared.dns_zone_public_name}"
  }
  set {
    name  = "controller.jenkinsAdminEmail"
    value = "vendor-corp-admins@sonatype.com"
  }
}

################################################################################
# Create Ingress for NXIQ
################################################################################
resource "kubernetes_ingress" "jenkins" {
  metadata {
    name      = "jenkins-ingress"
    namespace = var.target_namespace
    labels = {
      app = "jenkins"
    }
    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/group.name"      = "vencorcorp-shared-core"
      "alb.ingress.kubernetes.io/scheme"          = "internal"
      "alb.ingress.kubernetes.io/certificate-arn" = module.shared.vendorcorp_net_cert_arn
      "alb.ingress.kubernetes.io/success-codes"   = "200-403"
      # "alb.ingress.kubernetes.io/healthcheck-port" = "8071"
      # "alb.ingress.kubernetes.io/healthcheck-path" = "/healthcheck"
    }
  }

  spec {
    rule {
      host = "jenkins.corp.${module.shared.dns_zone_public_name}"
      http {
        path {
          path = "/*"
          backend {
            service_name = "jenkins"
            service_port = 8080
          }
        }
      }
    }
  }

  wait_for_load_balancer = true
}

################################################################################
# Add/Update DNS for Load Balancer Ingress
################################################################################
resource "aws_route53_record" "jenkins" {
  zone_id = module.shared.dns_zone_public_id
  name    = "jenkins.corp"
  type    = "CNAME"
  ttl     = "300"
  records = [
    kubernetes_ingress.jenkins.status.0.load_balancer.0.ingress.0.hostname
  ]
}
