provider "aws" {
  region = var.region
  profile = var.aws_profile
  default_tags {
    tags = var.project_tags
  }
}

# VPC resources for deploying EKS
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.name
  cidr = var.vpc_cidr

  azs = var.azs

  private_subnets = var.private_cidrs
  # Allows AWS Load Balancer Controller to identify private subnets
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  public_subnets = var.public_cidrs
  # Allows AWS Load Balancer Controller to public subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  map_public_ip_on_launch = true

  enable_nat_gateway = true

}

# The EKS cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "19.17.4"

  aws_auth_users = []
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }
  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs = var.cluster_public_access_cidr
  cluster_name = var.name
  # cluster_security_group_additional_rules = {}
  cluster_version = "1.28"
  # manage_aws_auth_configmap = true
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)
  vpc_id = module.vpc.vpc_id
  eks_managed_node_groups = {
    default = {
      use_custom_launch_template = false
    }
  }

}

# # Provide IAM roles for K8s ServiceAccounts to assume

module "ebs_csi_irsa_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "lb_controller_irsa_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# S3 / Athena resources

resource "aws_s3_bucket" "data" {
  bucket = var.s3_bucket_name
}

resource "aws_iam_role" "athena" {
  name = "superset-athena-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          "AWS": "${aws_iam_user.querier.arn}"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "athena" {
  name = "athena-cephalopod-s3-policy"
  role = aws_iam_role.athena.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetBucketLocation"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.data.arn}",
          "${aws_s3_bucket.data.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "athena_full_access" {
  role = aws_iam_role.athena.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}

resource "aws_iam_user" "querier" {
  name = "${var.name}_querier"
}

resource "aws_iam_access_key" "querier" {
  user = aws_iam_user.querier.name
}

resource "aws_athena_database" "bucket" {
  name = "lottery"
  bucket = aws_s3_bucket.data.id
}

resource "aws_athena_workgroup" "wg" {
  name = var.name
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data.bucket}/queries/"
    }
  }
}
