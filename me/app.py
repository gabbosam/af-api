import os
import re
import json
from datetime import datetime, timedelta
from pytz import timezone
import logging
import base64
import hashlib
import boto3
import hashlib
from boto3.dynamodb.conditions import Key
import jwt

# Static code used for DynamoDB connection and logging
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])
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
    try:
        item = table.get_item(ConsistentRead=True, Key={"login": jwt_token["sub"]})
        profile = item.get("Item")
        del profile["password"]
        profile["privacy"] = int(profile["privacy"])
    except Exception as ex:
        log.error(ex)
        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "User info failed"
            }),
            "headers": {
                "Access-Control-Allow-Origin": "*", 
                "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            }
        }

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message":"User profile",
            "token": token,
            "profile": profile
        }),
        "headers": {
            "Access-Control-Allow-Origin": "*", 
            "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
        }
    }