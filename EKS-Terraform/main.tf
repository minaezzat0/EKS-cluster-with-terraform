data "aws_availability_zones" "azs" {

}

# Create a VPC with two public subnets and two private subnets

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "my-vpc"
  cidr   = var.vpc_cidr_block
  azs    = data.aws_availability_zones.azs.names
  # private_subnets      = var.private_subnet_cidr_blocks
  public_subnets     = var.public_subnet_cidr_blocks
  enable_nat_gateway = true
  # single_nat_gateway   = true
  enable_dns_hostnames = true
  tags = {
    "kubernetes.io/cluster/eks_cluster" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/eks_cluster" = "shared"
    "kubernetes.io/role/elb"            = "1"
  }

  # private_subnet_tags = {
  #   "kubernetes.io/cluster/eks_cluster" = "shared"
  #   "kubernetes.io/role/internal-elb"   = "1"
  # }
}


# Create a security group for the node group
resource "aws_security_group" "eks_node_group" {
  name_prefix = "eks-cluster-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
resource "aws_security_group_rule" "eks_cluster_worker_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_node_group.id
}

# Create an EKS cluster in the VPC
resource "aws_eks_cluster" "eks_cluster" {
  name     = "interview-k8s-cluster"
  role_arn = "arn:aws:iam::333828806273:role/interview-k8s-cluster-ServiceRole"

  enabled_cluster_log_types = [
    "api",
    "audit"
  ]

  vpc_config {
    subnet_ids              = module.vpc.public_subnets
    endpoint_public_access  = true  
    endpoint_private_access = false
    security_group_ids = [
      aws_security_group.eks_node_group.id,
      aws_security_group_rule.eks_cluster_worker_ingress.security_group_id
    ]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
  depends_on = [aws_security_group_rule.eks_cluster_worker_ingress]
}



# Create a key pair named webserver_key in order to access the instance
resource "aws_key_pair" "worker_key" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa.public_key_openssh
}

# Create a private key
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the private key to a file
resource "local_file" "worker_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = var.key_file
}

# Associate the node group with the EKS cluster
resource "aws_eks_node_group" "eks_cluster_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "k8s-nodegroup"
  node_role_arn   = "arn:aws:iam::333828806273:role/interview-k8s-nodegroup-NodeInstanceRole"

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  # Use t2.micro instance type
  instance_types = ["t2.micro"]

  # Use public subnets
  subnet_ids = module.vpc.public_subnets

  remote_access {
    ec2_ssh_key = var.key_name
    source_security_group_ids = [
      aws_security_group.eks_node_group.id ,
      aws_security_group_rule.eks_cluster_worker_ingress.security_group_id

    ]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}



# resource "null_resource" "disable_oidc" {
#   depends_on = [aws_eks_cluster.eks_cluster]

#   provisioner "local-exec" {
#     command = "aws eks update-cluster-config --name ${aws_eks_cluster.eks_cluster.name}  --disable-openid-connect"
#   }
# }

