import boto3
import os
import json

ecs = boto3.client('ecs')
CLUSTER_NAME = os.environ['CLUSTER_NAME']
SERVICE_NAME = os.environ['SERVICE_NAME']

def lambda_handler(event, context):
    print(f"Secret rotation detected: {json.dumps(event)}")
    
    try:
        # Force a new deployment to pick up the new secret
        response = ecs.update_service(
            cluster=CLUSTER_NAME,
            service=SERVICE_NAME,
            forceNewDeployment=True
        )
        
        service_arn = response['service']['serviceArn']
        print(f"Triggered deployment for service {SERVICE_NAME}: {service_arn}")
        return {"status": "success", "service": service_arn}
        
    except Exception as e:
        print(f"Error triggering deployment: {str(e)}")
        raise e
