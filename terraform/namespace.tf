resource "kubernetes_namespace_v1" "vault" {
  metadata {
    name = var.vault_namespace
  }
}