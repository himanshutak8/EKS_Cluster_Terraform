# ==================================================================
# Karpenter — node autoscaling
# ==================================================================

# ------------------------------------------------------------------
# Karpenter submodule: controller IAM role (via Pod Identity), node IAM role, SQS interruption queue + EventBridge rules, and the cluster access entry for Karpenter-launched nodes.
# ------------------------------------------------------------------
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name                      = module.eks.cluster_name
  namespace                         = "karpenter"
  node_iam_role_use_name_prefix     = false
  node_iam_role_name                = "${local.cluster_name}-karpenter-node"
  create_pod_identity_association   = true
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  tags = {
    ManagedBy = "Terraform"
    Project   = "Learning Terraform"
  }
}

# ------------------------------------------------------------------
# ECR Public auth token (must be requested from us-east-1)
# ------------------------------------------------------------------
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr_public
}

# ------------------------------------------------------------------
# Karpenter controller (Helm)
# ------------------------------------------------------------------
resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.6.0" # check for latest 1.x before applying
  wait                = true    # ◀── CHANGE: was `false`. Waiting ensures the controller is fully deployed before creating the NodePool and EC2NodeClass resources.
  values = [
    <<-EOT
    settings:
      clusterName: ${module.eks.cluster_name}
      interruptionQueue: ${module.karpenter.queue_name}
    nodeSelector:              
      karpenter.sh/controller: "true"
    replicas: 2
    controller:
      env:
        - name: AWS_REGION
          value: ${var.aws_region}
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
    EOT
  ]
}

# ------------------------------------------------------------------
# ◀── CHANGE: EC2NodeClass + NodePool are now deployed through a local
#     Helm chart instead of two `kubectl_manifest` resources. This drops
#     the strict alekc/kubectl provider and enables a single apply.
# ------------------------------------------------------------------
resource "helm_release" "karpenter_resources" {
  name      = "karpenter-resources"
  namespace = "karpenter"
  chart     = "${path.module}/karpenter_resources"
  wait      = true
  timeout   = 600    #◀── CHANGE: was `300`. Karpenter may take longer to create its NodeClaims and drain nodes, so we give it more time.

  values = [yamlencode({
    clusterName  = module.eks.cluster_name
    nodeRoleName = module.karpenter.node_iam_role_name
  })]

  depends_on = [helm_release.karpenter]   # CRDs must exist first
}

# ------------------------------------------------------------------
# Destroy-time safety net: delete NodePools and wait for Karpenter to
# drain its nodes BEFORE the controller / node group are torn down.
# Prevents the finalizer deadlock ("context deadline exceeded").
# ------------------------------------------------------------------
resource "terraform_data" "karpenter_drain" {
  # Values captured here are the ONLY things a destroy provisioner may
  # reference (via self.*) — you can't use var.* or other resources at destroy.
  input = {
    cluster_name = module.eks.cluster_name
    region       = var.aws_region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      aws eks update-kubeconfig --name ${self.input.cluster_name} --region ${self.input.region}
      # Delete NodePools so Karpenter terminates the nodes it owns
      kubectl delete nodepool --all --ignore-not-found --timeout=300s || true
      # Wait until no NodeClaims remain (max ~5 min)
      for i in $(seq 1 30); do
        if [ -z "$(kubectl get nodeclaims -o name 2>/dev/null)" ]; then
          echo "All NodeClaims drained."
          break
        fi
        echo "Waiting for Karpenter to drain nodes... ($i/30)"
        sleep 10
      done
    EOT
  }

  depends_on = [helm_release.karpenter]
}

/*
##### Earlier we're using kubectl_manifest resources to deploy the EC2NodeClass and NodePool, but now we are using a local Helm chart for better management and deployment. 
##### The following resources are commented out as they are replaced by the Helm chart deployment above.
# ------------------------------------------------------------------
# EC2NodeClass — the "how": AMI, subnets, security groups, node role
# ------------------------------------------------------------------
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2023
      role: ${module.karpenter.node_iam_role_name}
      amiSelectorTerms:
        - alias: al2023@latest
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [helm_release.karpenter]
}

# ------------------------------------------------------------------
# NodePool — the "what": instance requirements, limits, consolidation
# ------------------------------------------------------------------
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "m", "r"]
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["4"]
          expireAfter: 720h
      limits:
        cpu: "1000"
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m
  YAML
  depends_on = [kubectl_manifest.karpenter_node_class]
}
*/