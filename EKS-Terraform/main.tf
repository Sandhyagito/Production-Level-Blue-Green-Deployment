provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "blue_green_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "blue-green-vpc"
  }
}

resource "aws_subnet" "blue_green_subnet" {
  count                  = 2
  vpc_id                 = aws_vpc.blue_green_vpc.id
  cidr_block             = cidrsubnet(aws_vpc.blue_green_vpc.cidr_block, 8, count.index)
  availability_zone      = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "blue-green-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "blue_green_igw" {
  vpc_id = aws_vpc.blue_green_vpc.id

  tags = {
    Name = "blue-green-igw"
  }
}

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

resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.blue_green_subnet[count.index].id
  route_table_id = aws_route_table.blue_green_route_table.id
}

resource "aws_security_group" "blue_green_cluster_sg" {
  vpc_id = aws_vpc.blue_green_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "blue-green-cluster-sg"
  }
}

resource "aws_security_group" "blue_green_node_sg" {
  vpc_id = aws_vpc.blue_green_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "blue-green-node-sg"
  }
}

resource "aws_eks_cluster" "blue_green" {
  name     = "blue-green-cluster"
  role_arn = aws_iam_role.blue_green_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.blue_green_subnet[*].id
    security_group_ids = [aws_security_group.blue_green_cluster_sg.id]
  }
}

resource "aws_eks_node_group" "blue_green" {
  cluster_name    = aws_eks_cluster.blue_green.name
  node_group_name = "blue-green-node-group"
  node_role_arn   = aws_iam_role.blue_green_node_group_role.arn
  subnet_ids      = aws_subnet.blue_green_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.large"]

  remote_access {
    ec2_ssh_key = "bluegreen-key"
    source_security_group_ids = [aws_security_group.blue_green_node_sg.id]
  }
}

resource "aws_iam_role" "blue_green_cluster_role" {
  name = "blue-green-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "blue_green_cluster_role_policy" {
  role       = aws_iam_role.blue_green_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "blue_green_node_group_role" {
  name = "blue-green-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "blue_green_node_group_role_policy" {
  role       = aws_iam_role.blue_green_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "blue_green_node_group_cni_policy" {
  role       = aws_iam_role.blue_green_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "blue_green_node_group_registry_policy" {
  role       = aws_iam_role.blue_green_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
