output "subnet_ids" {
  description = "Subnet IDs"
  value = [ for s in aws_subnet.main : s.id ]
}

output "instance_public_ip" {
  description = "Public IP of the HelloWorld instance"
  value       = aws_instance.instance.public_ip
}