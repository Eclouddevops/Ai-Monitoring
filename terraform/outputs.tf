output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.monitoring.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_eip.monitoring.public_ip
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_eip.monitoring.public_ip}:3001"
}

output "app_url" {
  description = "Node.js application URL"
  value       = "http://${aws_eip.monitoring.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_eip.monitoring.public_ip}:9090"
}

output "ssh_command" {
  description = "SSH command"
  value       = "ssh -i your-key.pem ubuntu@${aws_eip.monitoring.public_ip}"
}

output "ssm_command" {
  description = "SSM connect command (no SSH key needed)"
  value       = "aws ssm start-session --target ${aws_instance.monitoring.id} --region ${var.aws_region}"
}
