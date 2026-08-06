output "subnet_ids" {
  description = "Subnet IDs"
  value = [ for s in aws_subnet.main : s.id ]
}