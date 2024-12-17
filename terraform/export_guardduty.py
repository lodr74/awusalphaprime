import boto3
import json
import os
import datetime

# AWS Clients
s3 = boto3.client('s3')

# Parameters
RAW_BUCKET = os.environ['RAW_BUCKET']
TRANSFORM_BUCKET = os.environ['TRANSFORM_BUCKET']

def parse_guardduty_message(sns_message):
    """
    Parse the GuardDuty message and extract required fields.
    """
    try:
        message_data = json.loads(sns_message)     
        detail = message_data.get('detail', {})
        if len(detail) != 0:
            # Extract desired fields
            finding_id = detail.get('id', 'N/A')
            severity = detail.get('severity', 'N/A')
            created_at = detail.get('createdAt', 'N/A')
            threat_type = detail.get('type', 'N/A')
        else:
            # Extract desired fields
            finding_id = message_data.get('id','N/A')
            severity = message_data.get('severity', 'N/A')
            created_at = message_data.get('createdAt', 'N/A')
            threat_type = message_data.get('type', 'N/A')
        
        return {
            "finding_id": finding_id,
            "severity": severity,
            "created_at": created_at,
            "threat_type": threat_type
        }
    except json.JSONDecodeError as e:
        print(f"Error parsing GuardDuty message: {e}")
        return None

def export_transformed_findings(transformed_data):
    """
    Save the transformed GuardDuty findings to the TRANSFORM_BUCKET.
    """
    try:
        # Generate a timestamped filename for the transformed findings
        timestamp = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
        file_name = f'guardduty-transformed-{timestamp}.json'
        
        # Upload the transformed data to S3
        s3.put_object(
            Bucket=TRANSFORM_BUCKET,
            Key=file_name,
            Body=json.dumps(transformed_data, indent=4),
            ContentType='application/json'
        )
        print(f"Transformed findings exported to S3://{TRANSFORM_BUCKET}/{file_name}")
    except Exception as e:
        print(f"Error exporting transformed findings: {e}")

def lambda_handler(event, context):
    """
    AWS Lambda handler to process GuardDuty alerts and save transformed findings to S3.
    """
    try:
        # Log the incoming event
        print(f"Received event: {json.dumps(event)}")
        sns_message = json.dumps(event)
        # Parse the message and extract desired fields
        transformed_data = parse_guardduty_message(sns_message)
        if transformed_data:
            # Export the transformed findings to the TRANSFORM_BUCKET
            export_transformed_findings(transformed_data)
        else:
            print("Failed to parse GuardDuty message. Skipping...")
    except Exception as e:
        print(f"Error processing event: {e}")


