output "vpc_id" {
  value = module.vpc.vpc_id
}

output "web_url" {
  value = "http://${module.web.public_ip}"
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "db_endpoint" {
  value = module.db.endpoint
}

output "api_key_secret_arn" {
  value = module.web.api_key_secret_arn
}