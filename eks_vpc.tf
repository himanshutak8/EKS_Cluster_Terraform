terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

####To use the random string resource, we need to add the random provider to the required_providers block.####
locals {
  cluster_name = "eks-${random_string.suffix.result}"
}

####Generating Random String for Cluster Name Suffix(Failover to avoid name collision in case of multiple clusters)####
resource "random_string" "suffix" {
  length  = 8
  special = false
}
####To get the list of available availability zones in the specified region, we can use the aws_availability_zones data source.####
data "aws_availability_zones" "available" {}
provider "aws" {
  region = var.aws_region
}

####Using AWS VPC Module to create VPC, Subnets, Internet Gateway, NAT Gateway, Route Tables and Security Groups####
module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "6.0.1"
  name                 = var.vpc_name
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  public_subnet_names  = ["${var.vpc_name}-public-1", "${var.vpc_name}-public-2"]
  private_subnet_names = ["${var.vpc_name}-private-1", "${var.vpc_name}-private-2"]
  public_subnets       = var.public_subnet_cidrs
  private_subnets      = var.private_subnet_cidrs
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}