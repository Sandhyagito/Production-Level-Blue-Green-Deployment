output "cluster_id" {
  value = aws_eks_cluster.blue_green.id  # Updated to blue_green
}

output "node_group_id" {
  value = aws_eks_node_group.blue_green.id  # Updated to blue_green
}

output "vpc_id" {
  value = aws_vpc.blue_green_vpc.id  # Updated to blue_green_vpc
}

output "subnet_ids" {
  value = aws_subnet.blue_green_subnet[*].id  # Updated to blue_green_subnet
}
