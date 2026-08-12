##### About provider version
# The provider version is pinned to a specific version to ensure compatibility with the Terraform configuration.
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }
  }
}

##### Provider Configuration
provider "aws" {
  region = var.aws_region
}
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}