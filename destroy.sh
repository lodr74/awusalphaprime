#!/bin/bash

set -e  # Exit on error

# Variables
### You may not need the following line for your terrraform.  Mine just isnt in my $PATH
BIN="/Users/michaelleigh/bins/"
TERRAFORM_DIR="terraform"
ALERT_HANDLER_ZIP="$TERRAFORM_DIR/alert_handler.zip"
SLACK_ZIP="$TERRAFORM_DIR/slack.zip"
EXPORT_GD_SRC_ZIP="$TERRAFORM_DIR/export_guardduty.zip"
INV_GD_FINDINGS_ZIP="$TERRAFORM_DIR/InvestigateGuardDutyFindings.zip"

echo "=== Starting Deployment ==="

# Step 1: Create Lambda Deployment Package
echo "=== Tearing Down environment ==="
cd $TERRAFORM_DIR
$BIN/terraform destroy  -auto-approve

# Step 2: Initialize Terraform
echo "=== Removing Zip Files==="

# Remove the ZIP file
rm -f $ALERT_HANDLER_ZIP
rm -f $SLACK_ZIP
rm -f $EXPORT_GD_SRC_ZIP
rm -f $INV_GD_FINDINGS_ZIP

echo "Removed: $LAMBDA_ZIP"
echo "Removed: $SLACK_ZIP"
echo "Removed: $EXPORT_GD_SRC_ZIP"
echo "Removed: $INV_GD_FINDINGS_ZIP"


echo "=== Mass Carnage Complete ==="

