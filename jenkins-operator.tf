################################################################################
# Deploy Jenkins Operator (which deploys Jenkins Master)
################################################################################
resource "helm_release" "jenkins_operator" {
  name       = "jenkins-operator"
  repository = "https://raw.githubusercontent.com/jenkinsci/kubernetes-operator/master/chart"
  chart      = "jenkins-operator"
  version    = var.jeknins_operator_version
  namespace  = kubernetes_namespace.jenkins.metadata[0].name

  set {
    name = "jenkins.enabled"
    value = false
  }

  set {
    name = "jenkins.namespace"
    value = kubernetes_namespace.jenkins.metadata[0].name
  }
  
}