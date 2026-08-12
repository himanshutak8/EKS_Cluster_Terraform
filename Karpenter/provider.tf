terraform {
  required_version = ">= 1.6.0"          ###Tells about the minimum version of Terraform required to use this configuration.###
  required_providers { 
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
provider "aws" {
  region = var.aws_region
}

# ★ ADDED — ECR Public auth tokens are ONLY issued from us-east-1 (Karpenter chart lives there)
provider "aws" {
  alias  = "ecr_public"
  region = "us-east-1"
}

# ★ ADDED — short-lived token to auth the k8s/helm providers to the cluster
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# ★ ADDED — helm provider v3 uses the `kubernetes = { ... }` ATTRIBUTE syntax (not a block)
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# ★ ADDED
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
