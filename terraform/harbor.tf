resource "helm_release" "harbor" {
  name      = "harbor"
  namespace = "harbor"

  repository = "https://helm.goharbor.io"
  chart      = "harbor"

  values = [
    file("${path.module}/harbor-values.yaml")
  ]

  wait    = true
  timeout = 900
}