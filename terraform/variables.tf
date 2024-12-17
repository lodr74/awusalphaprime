variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "alert_email" {
  description = "Email address for receiving security alerts"
  type        = string
  default     = "<INSERT_EMAIL_HERE>"  #replace with your email
}

variable "aws_account_id" {
  description = "AWS Account ID"
  default     = "<INSERT_ACCTID_HERE>" # Replace with your account ID
}


variable "slack_webhook"{
  description = "Slacks Webhook for automateed alerting"
  default = "<INSERT_WEBHOOK_HERE>"  #replace with your email
}