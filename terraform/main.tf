####################################################################
##  Defining providers for AWS and Hashicorp
####################################################################

provider "aws" {
  region = var.region
}

terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.1"
    }
  }
}

####################################################################
##  End of defining providers
####################################################################






####################################################################
##  Defining some variable
####################################################################

data "aws_caller_identity" "current" {}

resource "time_sleep" "wait" {
  create_duration = "30s" # Pause for 30 seconds
}

resource "random_string" "bucket_id" {
  length  = 8
  special = false
  upper   = false
}

resource "random_string" "lambda_code_id" {
  length  = 8
  special = false
  upper   = false
}

####################################################################
##  End of section for Defining some variable
####################################################################








####################################################################
##  Enabling Security services
####################################################################


# GuardDuty
resource "aws_guardduty_detector" "main" {
  enable = true
    tags = {
    Name = "GuardDutyDetector"
  }
}


# Enable AWS Detective
resource "aws_detective_graph" "main" {
  tags = {
    Name = "DetectiveGraph"
  }
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  name                          = "cloudtrail-monitoring"
  s3_bucket_name                = aws_s3_bucket.logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  depends_on = [ time_sleep.wait ]
}


####################################################################
##  End of Section for Enabling Security services
####################################################################






#############################################################################
##  Upload Lambda Python SCripts and create Lambda Functions
#############################################################################


# Lambda ZIP Upload export_guardduty to S3
# This is the Lambda job for exporting Guardduty findings to an ETL Job
resource "aws_s3_object" "export_zip" {
  bucket = aws_s3_bucket.lambda_code.id
  key    = "export_guardduty.zip"
  source = "export_guardduty.zip" # Path to the local ZIP file
  etag   = filemd5("export_guardduty.zip")
}

resource "aws_lambda_function" "export_guardduty_findings" {
  function_name = "export_guardduty_findings"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "export_guardduty.lambda_handler"
  s3_bucket        = aws_s3_bucket.lambda_code.bucket
  s3_key           = aws_s3_object.export_zip.key

  environment {
    variables = {
      RAW_BUCKET       = aws_s3_bucket.guardduty_findings_raw.bucket
      TRANSFORM_BUCKET = aws_s3_bucket.guardduty_findings_transformed.bucket
      REGION = var.region
    }
  }
}


# Lambda ZIP Upload slack
# This is the Lambda job for sending GuardDuty alerts to Slack
# Webhook:   This is configured in variables.tf
resource "aws_s3_object" "slack_zip" {
  bucket = aws_s3_bucket.lambda_code.id
  key    = "slack.zip"
  source = "slack.zip" # Path to the local ZIP file
  etag   = filemd5("slack.zip")
}

resource "aws_lambda_function" "slack" {
  function_name = "slack"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "slack.lambda_handler"
  s3_bucket        = aws_s3_bucket.lambda_code.bucket
  s3_key           = aws_s3_object.slack_zip.key
  
  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook
    }
  }

  tags = {
    Name = "GuardDutyAlertHandler"
  }
}


# Lambda ZIP Upload slack
# This is the Lambda job for sending GuardDuty alerts to Slack
resource "aws_s3_object" "InvestigateGuardDutyFindings_zip" {
  bucket = aws_s3_bucket.lambda_code.id
  key    = "InvestigateGuardDutyFindings.zip"
  source = "InvestigateGuardDutyFindings.zip" # Path to the local ZIP file
  etag   = filemd5("InvestigateGuardDutyFindings.zip")
}

resource "aws_lambda_function" "InvestigateGuardDutyFindings" {
  function_name = "InvestigateGuardDutyFindings"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "InvestigateGuardDutyFindings.lambda_handler"
  s3_bucket        = aws_s3_bucket.lambda_code.bucket
  s3_key           = aws_s3_object.InvestigateGuardDutyFindings_zip.key
}

# Lambda ZIP Upload to S3
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_code.id
  key    = "alert_handler.zip"
  source = "alert_handler.zip" # Path to the local ZIP file
  etag   = filemd5("alert_handler.zip")
}

# Lambda Function
resource "aws_lambda_function" "alert_handler" {
  function_name    = "guardduty-alert-handler"
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  role             = aws_iam_role.lambda_execution_role.arn
  s3_bucket        = aws_s3_bucket.lambda_code.bucket
  s3_key           = aws_s3_object.lambda_zip.key

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }

  tags = {
    Name = "GuardDutyAlertHandler"
  }
}


# Upload the manifest file
resource "aws_s3_object" "manifest_file" {
  bucket = aws_s3_bucket.guardduty_findings_raw.id
  key    = "manifest.json"
  source = "manifest.json" # Path to the local ZIP file
  etag   = filemd5("manifest.json")
}



###################################################################################
##  End of sections for uploadin Lambda Python SCripts and create Lambda Functions
###################################################################################





############################################################################
## Create an SNS Notification Service
############################################################################

# SNS Topic for Notifications
resource "aws_sns_topic" "alerts" {
  name = "security-alerts"
}

# Add a subscription to the SNS Topic for Lambda Function to 
resource "aws_sns_topic_subscription" "guardduty_lambda_subscription_investigate_gd_findings" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.InvestigateGuardDutyFindings.arn
}

# Add a subscription to the SNS Topic for Lambda Function to export findings to send to an ETL Job that transforms
# the data to be imported into Athena for Quicksights dashboard
resource "aws_sns_topic_subscription" "guardduty_lambda_subscription_export_gd_findings" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.export_guardduty_findings.arn
}

# Add a subscription to the SNS Topic for Lambda Function to Slack for humean notification
resource "aws_sns_topic_subscription" "guardduty_lambda_subscription_slack" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack.arn
}


################################################################################
## Ending the SNS Section
################################################################################







###################################################################################
## Setting up the SNS Permissions to invoke Lambda
###################################################################################

# Grant SNS Permission to Invoke Lambda
resource "aws_lambda_permission" "sns_trigger_permission_slack" {
  statement_id  = "AllowSNSInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_lambda_permission" "sns_trigger_permission_InvestigateGuardDutyFindings" {
  statement_id  = "AllowSNSInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.InvestigateGuardDutyFindings.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}


resource "aws_lambda_permission" "sns_trigger_permission_export_guardduty_findings" {
  statement_id  = "AllowSNSInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.export_guardduty_findings.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}


################################################################################
## Ending the SNS PErmissions Section
################################################################################






##########################################################################################
##  Create S3 Buckets
##########################################################################################


# S3 Bucket for Lambda Code
resource "aws_s3_bucket" "lambda_code" {
  bucket = "lambda-code-bucket-${random_string.lambda_code_id.result}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "lambda_code_ownership" {
  bucket = aws_s3_bucket.lambda_code.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


# S3 bucket for GuardDuty

resource "aws_s3_bucket" "guardduty_findings_raw" {
  bucket = "guardduty-findings-raw-${var.aws_account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "guardduty_findings_raw_versioning" {
  bucket = aws_s3_bucket.guardduty_findings_raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket for GuardDuty Transformed

resource "aws_s3_bucket" "guardduty_findings_transformed" {
  bucket = "guardduty-findings-transformed-${var.aws_account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "guardduty_findings_transformed_versioning" {
  bucket = aws_s3_bucket.guardduty_findings_transformed.id

  versioning_configuration {
    status = "Enabled"
  }
}

# setting up encryption for GuardDuty Findings

resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty_findings_raw" {
  bucket = aws_s3_bucket.guardduty_findings_raw.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# setting up encryption for GuardDuty Findings transformed

resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty_findings_transformed" {
  bucket = aws_s3_bucket.guardduty_findings_transformed.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# S3 Bucket for CloudTrail Logs
resource "aws_s3_bucket" "logs" {
  bucket = "cloudtrail-logs-${random_string.bucket_id.result}"

   force_destroy = true
   tags = {
    Name = "CloudTrailLogs"
  }
}

resource "aws_s3_bucket_ownership_controls" "logs_ownership" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "logs_versioning" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}



##########################################################################################
##  End of S3 Buckets sections
##########################################################################################








##########################################################################################
##  Section for creating policies and Roles
##########################################################################################

# Cloud Trail Policies
resource "aws_s3_bucket_policy" "logs_policy" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSCloudTrailWrite",
        Effect    = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = "s3:PutObject",
        Resource = "${aws_s3_bucket.logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "AWSCloudTrailPermissionsCheck",
        Effect    = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action = "s3:GetBucketAcl",
        Resource = aws_s3_bucket.logs.arn
      }
    ]
  })
}


# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}


# Creating the S3 Bucket Policies for the previous GuardDuty S3 buckets

resource "aws_s3_bucket_policy" "guardduty_findings_policy" {
  bucket = aws_s3_bucket.guardduty_findings_raw.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGuardDutyToWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "guardduty.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "${aws_s3_bucket.guardduty_findings_raw.arn}/*"
    }
  ]
}
POLICY
}


# Creating the Policy for Lambda S3 Policy

resource "aws_iam_policy" "lambda_s3_policy" {
  name = "lambda_s3_policy"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.guardduty_findings_raw.arn}/*",
        "${aws_s3_bucket.guardduty_findings_transformed.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}


### Lambda GuardDuty Policy

resource "aws_iam_policy" "lambda_guardduty_policy" {
  name = "lambda_guardduty_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "guardduty:ListDetectors",
          "guardduty:ListFindings",
          "guardduty:GetFindings",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_guardduty_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_guardduty_policy.arn
}

resource "aws_iam_policy" "lambda_s3_put_policy" {
  name = "lambda-s3-put-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject"
        ],
        Resource =  [
                  "${aws_s3_bucket.guardduty_findings_raw.arn}/*",
                  "${aws_s3_bucket.guardduty_findings_transformed.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_put_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_s3_put_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}




##########################################################################################
##  End of Section for creating policies
##########################################################################################





####################################################################
## Event Bridge setup and configuration
####################################################################

# IAM Role for EventBridge Rule (optional if not using default)
resource "aws_sns_topic_policy" "sns_topic_policy" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action    = "sns:Publish",
        Resource  = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# EventBridge Rule for GuardDuty Findings
resource "aws_cloudwatch_event_rule" "guardduty_rule" {
  name        = "guardduty-finding-rule"
  description = "Rule to capture GuardDuty findings and send to SNS"
  event_pattern = jsonencode({
    source = ["aws.guardduty"]
  })
}

# EventBridge Target: Send GuardDuty Findings to SNS Topic
resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_rule.name
  target_id = "security-alerts"
  arn       = aws_sns_topic.alerts.arn
}

####################################################################
## End of Event Bridge Section
####################################################################


####################################################################
## Quicksights Access to S3
####################################################################

resource "aws_iam_role" "quicksight_role" {
  name = "quicksight-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "quicksight.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "quicksight_s3_access_policy" {
  name   = "QuickSightS3AccessPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:ListBucket"],
        Resource = [
          "${aws_s3_bucket.guardduty_findings_raw.arn}",
          "${aws_s3_bucket.guardduty_findings_transformed.arn}"
        ]
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObject"],
        Resource = [
          "${aws_s3_bucket.guardduty_findings_raw.arn}/*",
          "${aws_s3_bucket.guardduty_findings_transformed.arn}/*"
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "quicksight_s3_access_policy_attachment" {
  role       = aws_iam_role.quicksight_role.name
  policy_arn = aws_iam_policy.quicksight_s3_access_policy.arn
}



