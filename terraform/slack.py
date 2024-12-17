import json
import urllib3
import os

def lambda_handler(event, context):
    # Slack webhook URL from environment variables
    slack_webhook_url = os.environ['SLACK_WEBHOOK_URL']
    
    #creating a headless browser
    http = urllib3.PoolManager()

    # SNS message
    sns_message = event['Records'][0]['Sns']['Message']
    
    # Slack payload
    slack_payload = {
        "text": sns_message
    }
    
    # Post to Slack
    response = http.request('POST',
        slack_webhook_url,
        headers={'Content-Type': 'application/json'},
        body=json.dumps(slack_payload)
    )
    
    if response.status != 200:
        raise ValueError(f"Request to Slack returned error {response.status}, the response is: {response.data.decode('utf-8')}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Message sent to Slack')
    }