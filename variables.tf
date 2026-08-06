variable "region" {
  type    = string
  default = "us-east-1"
}
variable "route_table_name" {
  type    = string
  default = "main-rt"
}

variable "subnets" {
  type = map(string)
  default = {
    "us-east-1a" = "10.0.1.0/24"
    "us-east-1b" = "10.0.2.0/24"
    "us-east-1c" = "10.0.3.0/24"
  }
}