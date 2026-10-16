variable "aws_region" {
  description = "AWS region where the EKS cluster will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "voting-app-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EC2 instance type for the EKS managed node group."
  type        = string
  default     = "t3.medium"
}

variable "desired_node_count" {
  description = "Desired number of worker nodes in the node group."
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of worker nodes in the node group."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of worker nodes in the node group."
  type        = number
  default     = 5
}

variable "environment" {
  description = "Deployment environment label (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}
