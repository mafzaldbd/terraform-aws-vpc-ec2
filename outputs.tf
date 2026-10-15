output "vpc_id" {
  value = module.vpc.vpc_id
}

output "web_url" {
  value = "http://${module.web.public_ip}"
}