terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.20"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 2.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12"
    }
  }

  required_version = "= 1.2.3"
}
