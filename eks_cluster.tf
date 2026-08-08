module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  ####Here we're using local variable to generate a unique cluster name by appending a random string suffix to the base name "eks-" mentioned in eks_vpc.tf file. This helps avoid name collisions when creating multiple clusters.###
  name               = local.cluster_name
  kubernetes_version = var.eks_cluster_version

  # ------------------------------------------------------------------
  # Cluster Config & Networking
  # ------------------------------------------------------------------
  ####Modules creates an implicit dependency, so in case terraform modules we don't need to explicitly define dependencies(depends_on).
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets
  endpoint_private_access = true
  endpoint_public_access  = true
  ####Restrict public API access to your trusted CIDRs. Replace this with your office/VPN/public IP.
  endpoint_public_access_cidrs = var.eks_public_access_cidrs
  ####Controls who gets administrative access to the EKS cluster when the cluster is created(local_mac-> awscli_user).
  enable_cluster_creator_admin_permissions = true

  # ------------------------------------------------------------------
  # Cluster Security Group
  # ------------------------------------------------------------------
  create_security_group = true
  security_group_name        = "${local.cluster_name}-cluster-sg"
  security_group_description = "Security group for EKS cluster"
  security_group_additional_rules = {
    # Allow HTTPS from trusted networks to Kubernetes API
    ingress_https = {
      description = "Allow Kubernetes API access from trusted networks"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = var.eks_public_access_cidrs
    }
  }

  # ------------------------------------------------------------------
  # EKS Managed Node Groups
  # ------------------------------------------------------------------

  eks_managed_node_groups = {
    general = {
      name = "${local.cluster_name}-general"
      subnet_ids = module.vpc.private_subnets
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size
      instance_types = var.node_instance_types
      capacity_type = "ON_DEMAND"
      ami_type = "AL2023_x86_64_STANDARD"
      disk_size = 50
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
      create_security_group = true
      tags = {
        Name = "${local.cluster_name}-general-node"
      }
    }
  }

  # ------------------------------------------------------------------
  # Cluster Add-ons
  # ------------------------------------------------------------------

  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      before_compute = true ###Need to install before compute add-on to avoid issues with CNI plugin and node group creation.###
    }
    eks-pod-identity-agent = {
      most_recent = true
      before_compute = true ###Need to install before compute add-on to avoid issues with CNI plugin and node group creation.###
    }
  }

  tags = {
    ManagedBy   = "Terraform"
    Project     = "Lucidity_Project"
  }
}