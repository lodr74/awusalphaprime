import boto3
import json

def lambda_handler(event, context):
    # Parse the SNS message
    sns_message = event['Records'][0]['Sns']['Message']
    finding = json.loads(sns_message)
    
    # Extract finding details
    finding_type = finding.get("type")
    severity = finding.get("severity")
    resource = finding.get("resource", {}).get("instanceDetails", {}).get("instanceId")
    region = finding.get("region")

    print(f"Investigating GuardDuty Finding: {finding_type}")
    print(f"Severity: {severity}, Resource: {resource}, Region: {region}")

    # Perform investigation steps
    ec2 = boto3.client('ec2', region_name=region)
    detective = boto3.client('detective', region_name=region)
    
    # Example: Tag the resource for further analysis
    if resource:
        ec2.create_tags(
            Resources=[resource],
            Tags=[{'Key': 'GuardDuty-Investigation', 'Value': 'Triggered'}]
        )
        print(f"Tagged resource {resource} for investigation.")
    
    # Example: Automatically send to Amazon Detective
    if finding_type and detective:
        print("Sending finding to Amazon Detective for analysis...")
        # (Amazon Detective processes findings automatically if enabled)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Investigation complete.')
    }
