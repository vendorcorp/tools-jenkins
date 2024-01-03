# ################################################################################
# # k8s Namespace
# ################################################################################
# resource "kubernetes_namespace" "jenkins_iday" {
#   metadata {
#     name = "jenkins-iday"
#   }
# }

# ################################################################################
# # Jenkins Installation
# ################################################################################
# resource "kubernetes_manifest" "jenkins_iday" {
#   manifest = yamldecode(file("instances/iday.yaml"))
# }

# ################################################################################
# # Create Ingress for jenkins_iday
# ################################################################################
# # resource "kubernetes_ingress_v1" "jeknins_iday" {
# #   metadata {
# #     name      = "jeknins-iday-ingress"
# #     namespace = "jenkins-iday"
# #     labels = {
# #       app = "jenkins-iday"
# #     }
# #     annotations = {
# #       "kubernetes.io/ingress.class"               = "alb"
# #       "alb.ingress.kubernetes.io/group.name"      = "vendorcorp-shared"
# #       "alb.ingress.kubernetes.io/scheme"          = "internal"
# #       "alb.ingress.kubernetes.io/certificate-arn" = module.shared_private.bma_cert_arn
# #       "external-dns.alpha.kubernetes.io/hostname" = "iday-jenkins.${module.shared_private.dns_zone_bma_name}"
# #     }
# #   }

# #   spec {
# #     rule {
# #       host = "iday-jenkins.${module.shared_private.dns_zone_bma_name}"
# #       http {
# #         path {
# #           path = "/*"
# #           backend {
# #             service {
# #               name = "keycloak-service"
# #               port {
# #                 number = 8080
# #               }
# #             }
# #           }
# #         }
# #       }
# #     }
# #   }

# #   wait_for_load_balancer = true
# # }