resource "kubernetes_namespace_v1" "awx" {
  metadata {
    name = var.awx_namespace
  }
}

resource "helm_release" "awx" {
  name      = "awx"
  namespace = "awx"

  repository = "https://ansible-community.github.io/awx-operator-helm/"
  chart      = "awx-operator"
  version    = var.awx_operator_chart_version

  values = [
    file("${path.module}/awx-values.yaml")
  ]
  wait    = true
  timeout = 900
}