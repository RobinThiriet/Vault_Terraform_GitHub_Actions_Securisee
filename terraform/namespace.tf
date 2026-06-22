resource "kubernetes_namespace_v1" "vault" {
  metadata {
    name = var.vault_namespace
  }
}

resource "kubernetes_namespace_v1" "harbor" {
  metadata {
    name = "harbor"
  }
}