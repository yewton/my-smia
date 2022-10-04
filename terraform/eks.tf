module "vpc_cni_irsa" {
  source  = "registry.terraform.io/terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 4.12"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv6   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

module "ebs_csi_irsa" {
  source  = "registry.terraform.io/terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 4.12"

  role_name_prefix      = "EBS-CSI-IRSA"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "eks" {
  source  = "registry.terraform.io/terraform-aws-modules/eks/aws"
  version = "~> 18.29.0"

  cluster_name                    = local.cluster_name
  cluster_version                 = local.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  enable_irsa                     = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni    = {
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
    aws-ebs-csi-driver = {
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  eks_managed_node_groups = {
    ostock = {
      ami_type       = "AL2_x86_64"
      platform       = "linux"
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["m4.large"]
      capacity_type  = "SPOT"
      disk_size      = 20

      iam_role_attach_cni_policy = true # デフォルトだけど明示しておく

      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
      #      create_launch_template = false
      #      launch_template_name   = ""

      #      remote_access = {
      #        ec2_ssh_key               = module.key_pair.key_pair_name
      #        source_security_group_ids = [aws_security_group.allow-myip.id]
      #      }

      key_name               = module.key_pair.key_pair_name
      vpc_security_group_ids = [
        aws_security_group.allow-myip.id,
        aws_security_group.ostock.id
      ]
    }
  }
}

data "aws_instance" "eks_managed" {
  instance_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
  depends_on = [module.eks]
}

data "aws_caller_identity" "current" {}

module "ecr" {
  source  = "registry.terraform.io/terraform-aws-modules/ecr/aws"
  version = "~> 1.4.0"

  for_each = toset([
    "config-server", "gateway-server", "eureka-server",
    "authentication-service", "licensing-service", "organization-service"
  ])

  repository_name = "ostock/${each.key}"

  repository_read_write_access_arns = [data.aws_caller_identity.current.arn]
  create_lifecycle_policy           = true
  repository_lifecycle_policy       = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last n images",
        selection    = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 5
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  repository_force_delete = true
}
