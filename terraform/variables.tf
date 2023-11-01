variable "region" {
  description = "The AWS region to deploy to."
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  default = "cephalopodus-gigantus"
}

variable "azs" {
  description = "AZs within which to deploy subnets"
  default = ["us-east-1a", "us-east-1b"]
}

variable "aws_profile" {
  description = "The AWS cli profile to use"
  default     = "dylan-aws1"
}

variable "k8s_context" {
  description = "The kubeconfig context to use"
  default = "cephalopod"
}

variable "project_tags" {
  description = "Tag to apply to all resources in the project"
  default     = {
    Terraform = "true"
    Environment = "dev"
    Project = "cephalopod"
  }
}

variable "name" {
  description = "Name of project to be used across all resources"
  default = "cephalopod"
}

variable "vpc_cidr" {
  description = "CIDR for created VPC"
  default = "172.18.0.0/16"
}

variable "private_cidrs" {
  description = "CIDRs for private subnets"
  default = ["172.18.1.0/24","172.18.2.0/24"]
}

variable "public_cidrs" {
  description = "CIDRs for public subnets"
  default = ["172.18.3.0/24","172.18.4.0/24"]
}

variable "cluster_public_access_cidr" {
  description = "CIDRs you want to grant public access to EKS API"
  type = list(string)
  default = ["76.71.157.53/32"] # your machine
}