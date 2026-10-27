module "vpc" {
  source               = "./modules/vpc"
  project              = var.project
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "ecr" {
  source  = "./modules/ecr"
  project = var.project
}

module "web" {
  source             = "./modules/ec2"
  project            = var.project
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnet_ids[0]
  instance_type      = var.instance_type
  ecr_repository_url = module.ecr.repository_url
  db_endpoint        = module.db.endpoint
  db_name            = module.db.db_name
  db_secret_arn      = module.db.master_secret_arn
}

module "db" {
  source                    = "./modules/rds"
  project                   = var.project
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  allowed_security_group_id = module.web.security_group_id
}