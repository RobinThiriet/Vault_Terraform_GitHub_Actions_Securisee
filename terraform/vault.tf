resource "helm_release" "vault" {
  name      = "vault"
  namespace = "vault"

  depends_on = [
    kubernetes_namespace_v1.vault
  ]

  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"

  values = [
    file("${path.module}/value-vault.yaml")
  ]

  wait    = true
  timeout = 600
}