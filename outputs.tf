output "vpc_id" {
  value = aws_vpc.main.id
}

output "web_url" {
  value = "http://${aws_instance.web.public_ip}"
}