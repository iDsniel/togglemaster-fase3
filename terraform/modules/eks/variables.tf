variable "cluster_name" {
  description = "Amazon EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS cluster and node group"
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to access the public EKS API endpoint"
  type        = list(string)
}

variable "admin_principal_arn" {
  description = "IAM principal granted administrative Kubernetes access"
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types used by the managed node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_max_size" {
  type    = number
  default = 4
}
