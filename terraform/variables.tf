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
variable "awx_namespace" {
  description = "Namespace Kubernetes pour AWX"
  type        = string
  default     = "awx"
}

variable "awx_operator_chart_version" {
  description = "Version du chart Helm awx-operator"
  type        = string
  default     = null
}