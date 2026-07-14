output "instance_ids" {
  description = "IDs of EC2 instances"
  value       = aws_instance.monitoring[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses of EC2 instances"
  value       = aws_eip.monitoring[*].public_ip
}

output "monitoring_server_ip" {
  description = "Public IP of the monitoring server (instance 1)"
  value       = aws_eip.monitoring[0].public_ip
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_eip.monitoring[0].public_ip}:3001"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
