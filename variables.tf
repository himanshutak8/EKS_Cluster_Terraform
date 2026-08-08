# ============================================================
# VPC Variables
# ============================================================
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_name" {
  type    = string
  default = "eks-vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = [
    "192.168.1.0/24",
    "192.168.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = [
    "192.168.11.0/24",
    "192.168.12.0/24"
  ]
}

# ============================================================
# EKS Cluster Variables
# ============================================================

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.35"
}
variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to access EKS Kubernetes API"
  type        = list(string)
  default = [
    "0.0.0.0/0"
  ]
}
variable "node_group_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}
variable "node_group_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}
variable "node_group_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}
variable "node_instance_types" {
  description = "EC2 instance types for EKS managed node group"
  type        = list(string)
  default = [
    "t3.medium"
  ]
}