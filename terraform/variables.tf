variable "kubeconfig_path" {
  description = "Path vers le kubeconfig k3s"
  type        = string
  default     = "~/.kube/config"
}

variable "vault_namespace" {
  description = "Namespace Kubernetes pour Vault"
  type        = string
  default     = "vault"
}
