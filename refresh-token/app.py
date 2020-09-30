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
table = dynamodb.Table(os.environ['TABLE_NAME'])
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

    refresh_token = jwt.decode(token, token_key, algorithm=['HS256'])
    
    item = table_tokens.get_item(ConsistentRead=True, Key={"uuid": refresh_token["uuid"]})
    if item.get('Item') is not None:
        token = item.get('Item').get("token")
        try:
            payload = jwt.decode(token, token_key, algorithm=['HS256'])
        except jwt.ExpiredSignatureError as ex:
            log.info("Token expired, refresh")
            payload = None
        except jwt.InvalidSignatureError as ex:
            log.info("Invalid signature")
            return {
                "statusCode": 401,
                "body": json.dumps({"message":"Invalid signature"}),
                "headers": {
                    "Access-Control-Allow-Origin": "*", 
                    "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
                    "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
                }
            }
        issued_at = datetime.today()
        exp_at = issued_at + timedelta(minutes=int(os.getenv("TOKEN_DURATION")))
        
        if not payload:
            payload = jwt.decode(token, token_key, algorithm=['HS256'], verify=False)

        #token_uuid = str(uuid.uuid4())
        payload["iat"] = issued_at
        payload["exp"] = exp_at
        #payload["uuid"] = token_uuid

        jwt_token = jwt.encode(payload, token_key, algorithm='HS256').decode()
        refresh_exp_at = issued_at + timedelta(days=5)
        refresh_uuid = refresh_token["uuid"]
        refresh_token = jwt.encode(
            {
                "sub": "af-api",
                "iat": issued_at.timestamp(),
                "exp": refresh_exp_at.timestamp(),
                "uuid": refresh_uuid
            }, 
            token_key, algorithm='HS256'
        ).decode()
        log.debug("REFRESH JWT token:" + refresh_token)
        with table_tokens.batch_writer() as batch:
            batch.put_item(
                {
                    "uuid": refresh_uuid,
                    "token": jwt_token
                }
            )
            # batch.delete_item(
            #     Key = {
            #         "uuid": exp_uuid
            #     }
            # )
        
    else:
        return {
            "statusCode": 403,
            "body": json.dumps({"message": "Unknown session, try new login"}),
            "headers": {
                "Access-Control-Allow-Origin": "*", 
                "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            }
        }

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Login successful",
            "token": jwt_token,
            "refresh_token": refresh_token
        }),
        "headers": {
            "Access-Control-Allow-Origin": "*", 
            "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
        }
    }