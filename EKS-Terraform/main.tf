provider "aws" {
  region = "us-east-1"  # Replace with your desired region
}

# Create VPC
resource "aws_vpc" "blue_green_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "blue-green-vpc"
  }
}

# Create Subnets
resource "aws_subnet" "blue_green_subnet" {
  count = 2
  vpc_id = aws_vpc.blue_green_vpc.id
  cidr_block = "10.0.${count.index}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "blue-green-subnet-${count.index + 1}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "blue_green_igw" {
  vpc_id = aws_vpc.blue_green_vpc.id
  tags = {
    Name = "blue-green-igw"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "blue_green_route_table" {
  vpc_id = aws_vpc.blue_green_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.blue_green_igw.id
  }
  tags = {
    Name = "blue-green-route-table"
  }
}

# Route Table Associations
resource "aws_route_table_association" "blue_green_subnet_association" {
  count = 2
  subnet_id = aws_subnet.blue_green_subnet[count.index].id
  route_table_id = aws_route_table.blue_green_route_table.id
}

# Create Security Groups for EKS Cluster
resource "aws_security_group" "blue_green_cluster_sg" {
  vpc_id = aws_vpc.blue_green_vpc.id
  tags = {
    Name = "blue-green-cluster-sg"
  }
}

resource "aws_security_group" "blue_green_node_sg" {
  vpc_id = aws_vpc.blue_green_vpc.id
  tags = {
    Name = "blue-green-node-sg"
  }
}

# Create EKS Cluster
resource "aws_eks_cluster" "blue_green" {
  name     = "blue-green-cluster"
  role_arn = aws_iam_role.blue_green_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.blue_green_subnet[*].id
    security_group_ids = [aws_security_group.blue_green_cluster_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.blue_green_cluster_role_policy]
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "blue_green_cluster_role" {
  name = "blue-green-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
}

# IAM Role Policy Attachment for EKS Cluster
resource "aws_iam_role_policy_attachment" "blue_green_cluster_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.blue_green_cluster_role.name
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "blue_green_node_group_role" {
  name = "blue-green-node-group-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
}

# IAM Role Policy Attachments for EKS Node Group
resource "aws_iam_role_policy_attachment" "blue_green_node_group_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.blue_green_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "blue_green_node_group_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.blue_green_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "blue_green_node_group_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.blue_green_node_group_role.name
}

# Create EKS Node Group
resource "aws_eks_node_group" "blue_green" {
  cluster_name    = aws_eks_cluster.blue_green.name
  node_group_name = "blue-green-node-group"
  node_role_arn   = aws_iam_role.blue_green_node_group_role.arn
  subnet_ids      = aws_subnet.blue_green_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 2
  }
}

# OIDC Provider for EKS Cluster
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [aws_eks_cluster.blue_green.identity[0].oidc.issuer]
  url = aws_eks_cluster.blue_green.identity[0].oidc.issuer
}


