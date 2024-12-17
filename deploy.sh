#!/bin/bash

set -e  # Exit on error

# Variables
### You may not need the following line for your terrraform.  Mine just isnt in my $PATH
BIN="/Users/michaelleigh/bins/"
TERRAFORM_DIR="terraform"
ALERT_HANDER_SRC="alert_handler.js"
SLACK_HANDLER_SRC="$TERRAFORM_DIR/slack.py"
EXPORT_GD_SRC="$TERRAFORM_DIR/export_guardduty.py"
INV_GD_FINDINGS="$TERRAFORM_DIR/InvestigateGuardDutyFindings.py"
ALERT_HANDLER_ZIP="$TERRAFORM_DIR/alert_handler.zip"
SLACK_ZIP="$TERRAFORM_DIR/slack.zip"
EXPORT_GD_SRC_ZIP="$TERRAFORM_DIR/export_guardduty.zip"
INV_GD_FINDINGS_ZIP="$TERRAFORM_DIR/InvestigateGuardDutyFindings.zip"

echo "=== Starting Deployment ==="

# Step 1: Create Lambda Deployment Package
echo "=== Building Lambda Function Package ==="
# Create the ZIP file
zip -j $ALERT_HANDLER_ZIP $ALERT_HANDER_SRC
zip -j $SLACK_ZIP $SLACK_HANDLER_SRC
zip -j $EXPORT_GD_SRC_ZIP $EXPORT_GD_SRC
zip -j $INV_GD_FINDINGS_ZIP $INV_GD_FINDINGS

echo "Lambda package created: $LAMBDA_ZIP"
echo "Lambda package created: $SLACK_ZIP"
echo "Lambda package created: $EXPORT_GD_SRC_ZIP"
echo "Lambda package created: $INV_GD_FINDINGS_ZIP"

# Step 2: Initialize Terraform
echo "=== Initializing Terraform ==="
cd $TERRAFORM_DIR
$BIN/terraform init

# Step 3: Validate Terraform Configuration
echo "=== Validating Terraform Configuration ==="
$BIN/terraform validate

# Step 4: Apply Terraform Configuration
echo "=== Applying Terraform Plan ==="
$BIN/terraform apply -auto-approve

# Step 5: Output Terraform Information
echo "=== Terraform Outputs ==="
$BIN/terraform output

echo "=== Deployment Complete ==="

