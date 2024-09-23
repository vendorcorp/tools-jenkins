################################################################################
# k8s Namespace
################################################################################
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

################################################################################
# Jenkins Instance Configuration
################################################################################
resource "kubernetes_config_map" "jenkins_configuration" {
    metadata {
        name = "jenkins-configuration"
        namespace = kubernetes_namespace.jenkins.metadata[0].name
    }

    data = {
        "1-base-system.yaml" = <<-EOD
jenkins:
    noUsageStatistics: true
    systemMessage: "This is Jenkins for VendorCorp (${terraform.workspace}) - all configuration of Jenkins is managed in code!"
EOD
        "2-security.yaml" = <<-EOD
jenkins:
    securityRealm:
    keycloak:
        keycloakJson: |-
        {
            "realm": "VendorCorp",
            "auth-server-url": "https://keycloak.eu1.corp.vendorcorp.net/",
            "ssl-required": "external",
            "resource": "jenkins",
            "public-client": true,
            "confidential-port": 0
        }
        keycloakRespectAccessTokenTimeout: false
        keycloakValidate: false
EOD
        "9-unclassified.yaml" = <<-EOD
unclassified:
    location:
        adminAddress: no-reply@${module.shared_private.dns_zone_vendorcorp_name}
        url: https://jenkins.${module.shared_private.dns_zone_vendorcorp_name}
EOD
    }
}

################################################################################
# Jenkins Instance
################################################################################
resource "kubernetes_manifest" "jenkins_instance" {
    field_manager {
        force_conflicts = true
        name = "manager"
    }
    manifest = {
        "apiVersion": "jenkins.io/v1alpha2",
        "kind": "Jenkins",
        "metadata": {
            "name": "jenkins-${terraform.workspace}",
            "namespace": "${kubernetes_namespace.jenkins.metadata[0].name}"
        },
        "spec": {
            "configurationAsCode": {
                "configurations": [
                    {
                        "name": "jenkins-configuration"
                    }
                ],
                "secret": {
                    "name": ""
                }
            },
            "groovyScripts": {
                "configurations": [],
                "secret": {
                    "name": ""
                }
            },
            "jenkinsAPISettings": {
                "authorizationStrategy": "createUser"
            },
            "master": {
                "basePlugins": [
                    {
                        "name": "configuration-as-code",
                        "version": "1850.va_a_8c31d3158b_"
                    },
                    {
                        "name": "git",
                        "version": "5.5.1"
                    },
                    {
                        "name": "job-dsl",
                        "version": "1.89"
                    },
                    {
                        "name": "kubernetes",
                        "version": "4290.v93ea_4b_b_26a_61"
                    },
                    {
                        "name": "kubernetes-credentials-provider",
                        "version": "1.262.v2670ef7ea_0c5"
                    },
                    {
                        "name": "workflow-aggregator",
                        "version": "600.vb_57cdd26fdd7"
                    },
                    {
                        "name": "workflow-job",
                        "version": "1436.vfa_244484591f"
                    }
                ],
                "plugins": [
                    {
                        "name": "keycloak",
                        "version": "2.3.2"
                    }
                ],
                "disableCSRFProtection": false,
                "containers": [{
                    "name": "jenkins-master",
                    "image": "jenkins/jenkins:2.462.2-lts",
                    "imagePullPolicy": "Always",
                    "livenessProbe": {
                        "failureThreshold": 12,
                        "httpGet": {
                            "path": "/login",
                            "port": "http",
                            "scheme": "HTTP"
                        },
                        "initialDelaySeconds": 100,
                        "periodSeconds": 10,
                        "successThreshold": 1,
                        "timeoutSeconds": 5
                    },
                    "readinessProbe": {
                        "failureThreshold": 10,
                        "httpGet": {
                            "path": "/login",
                            "port": "http",
                            "scheme": "HTTP"
                        },
                        "initialDelaySeconds": 80,
                        "periodSeconds": 10,
                        "successThreshold": 1,
                        "timeoutSeconds": 1
                    },
                    "resources": {
                        "limits": {
                            "cpu": "1500m",
                            "memory": "3Gi"
                        },
                        "requests": {
                            "cpu": "1",
                            "memory": "500Mi"
                        }
                    }
                }]
            },
            "service": {
                "port": 8080,
                "type": "NodePort"
            }
        }
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
      "alb.ingress.kubernetes.io/certificate-arn" = module.shared_private.vendorcorp_cert_arn
      "external-dns.alpha.kubernetes.io/hostname" = "jenkins.${module.shared_private.dns_zone_vendorcorp_name}"
    }
  }

  spec {
    rule {
      host = "jenkins.${module.shared_private.dns_zone_vendorcorp_name}"
      http {
        path {
          path = "/*"
          backend {
            service {
              name = "jenkins-operator-http-jenkins-${terraform.workspace}"
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
        "tools-jenkins-jenkins.${module.shared_private.dns_zone_vendorcorp_name}": <<EOD
endpoints:
- name: "Jenkins"
    group: "vendorcorp"
    url: "https://jenkins.${module.shared_private.dns_zone_vendorcorp_name}/login"
    interval: 1m
    conditions:
    - "[STATUS] == 200"         # Status must be 200
    - "[RESPONSE_TIME] < 300"   # Response time must be under 300ms
    EOD
    }
}