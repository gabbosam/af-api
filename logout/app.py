import os
import re
import uuid
import json
from datetime import datetime, timedelta
import logging
import base64
import hashlib
import boto3

import jwt

# Static code used for DynamoDB connection and logging
dynamodb = boto3.resource('dynamodb')
table_tokens = dynamodb.Table("tokens")
log_level = os.environ['LOG_LEVEL']
log = logging.getLogger(__name__)
logging.getLogger().setLevel(log_level)

def lambda_function(event, context):
    log.debug("Event: " + json.dumps(event))
    token_key = event["stageVariables"]["HK"]

    authorizationHeader = {k.lower(): v for k, v in event['headers'].items() if k.lower() == 'authorization'}
    token = authorizationHeader["authorization"].split()[1]
    log.debug("JWT Token: {}".format(token))

    jwt_token = jwt.decode(token, token_key, algorithm=['HS256'])
    
    exp_uuid = jwt_token["uuid"]
    item = table_tokens.get_item(ConsistentRead=True, Key={"uuid": exp_uuid})
    if item.get("Item"):
        with table_tokens.batch_writer() as batch:
            batch.delete_item(
                Key = {
                    "uuid": exp_uuid
                }
            )
    else:
        return {
            "statusCode": 403,
            "body": json.dumps({
                "message": "Unknown session, try new login"
            }),
            "headers": {
                "Access-Control-Allow-Origin": "*", 
                "Access-Control-Allow-Credentials": True, 
                "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
                "Access-Control-Allow-Methods": "POST, OPTIONS"
            }
        }
    
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Logout successful"
        }),
        "headers": {
            "Access-Control-Allow-Origin": "*", 
            "Access-Control-Allow-Credentials": True, 
            "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "POST, OPTIONS"
        }
    }