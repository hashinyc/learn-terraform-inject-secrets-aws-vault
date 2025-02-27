variable "name" { default = "dynamic-aws-creds-operator" }
variable "region" { default = "us-east-1" }
variable "path" { default = "../vault-admin-workspace/terraform.tfstate" }
variable "ttl" { default = "1" }

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

data "terraform_remote_state" "admin" {
  backend = "remote"

  config = {
    path = var.path
  }
}


   
provider "vault" {
  # HCP Vault Configuration options
  address = var.vault_address
  namespace = var.vault_namespace
  auth_login {
    path = "auth/userpass/login/${var.login_username}"
    namespace = var.vault_namespace
    
    parameters = {
      password = var.login_password
    }
  }
  
}

# ask Vault to get credentials to use for deployment to AWS
data "vault_aws_access_credentials" "aws_creds" {
  backend = "aws"
  role     = "cloud_user"
}


provider "aws" {
  region     = var.region
  access_key = data.vault_aws_access_credentials.creds.access_key
  secret_key = data.vault_aws_access_credentials.creds.secret_key
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create AWS EC2 Instance
resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.nano"

  tags = {
    Name  = var.name
    TTL   = var.ttl
    owner = "${var.name}-guide"
  }
}
