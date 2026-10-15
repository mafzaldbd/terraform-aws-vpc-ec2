variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "instance_type" {
  type = string
}