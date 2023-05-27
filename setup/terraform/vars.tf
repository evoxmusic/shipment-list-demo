variable "env" {
  type        = string
  description = "dev env"
  default = ""
}

# need to create TF_VAR_sns_sub_endpoint env var on Qovery
variable "sns_sub_endpoint" {
  type        = string
  description = "SNS subscriber endpoint"
  default = "https://localhost:8081/sns/notifications"
}