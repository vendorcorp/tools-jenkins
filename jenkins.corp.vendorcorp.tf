################################################################################
# k8s Namespace
################################################################################
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "vc-jenkins"
  }
}

################################################################################
# Deploy Jenkins Operator (which deploys Jenkins Master)
################################################################################
resource "helm_release" "jenkins_operator" {
  name       = "jenkins-operator"
  repository = "https://raw.githubusercontent.com/jenkinsci/kubernetes-operator/master/chart"
  chart      = "jenkins-operator"
  version    = var.jeknins_operator_version
  namespace  = kubernetes_namespace.jenkins.metadata[0].name

  # See https://jenkinsci.github.io/kubernetes-operator/docs/getting-started/latest/installing-the-operator/#configuring-operator-deployment
  values = [
    "${file("values/jenkins.corp.vendorcorp.net.yaml")}"
  ]

  set {
    name  = "jenkins.namespace"
    value = kubernetes_namespace.jenkins.metadata[0].name
  }
}

################################################################################
# Create Ingress for Jenkins Master
################################################################################
resource "kubernetes_ingress_v1" "jenkins" {
  metadata {
    name      = "jeknins"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
    labels = {
      app = "jenkins-operator"
    }
    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/group.name"      = "vendorcorp-shared"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/login"
      "alb.ingress.kubernetes.io/scheme"          = "internal"
      "alb.ingress.kubernetes.io/certificate-arn" = module.shared.vendorcorp_net_cert_arn
      "external-dns.alpha.kubernetes.io/hostname" = "jenkins.corp.${module.shared.dns_zone_public_name}"
    }
  }

  spec {
    rule {
      host = "jenkins.corp.${module.shared.dns_zone_public_name}"
      http {
        path {
          path = "/*"
          backend {
            service {
              name = "jenkins-operator-http-jenkins"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true
}

################################################################################
# Create ConfigMap for gatus monitoring
################################################################################
resource "kubernetes_config_map" "gatus" {
  metadata {
    name = "gatus-config"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
    labels = {
      "gatus.io/enabled": "true"
    }
  }

  data = {
    "tools-jenkins-jenkins.corp.vendorcorp.yaml": "${file("values/jenkins.corp.vendorcorp.net-gatus.yaml")}"
  }
}