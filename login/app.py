import os
import re
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
log_level = os.environ['LOG_LEVEL']
log = logging.getLogger(__name__)
logging.getLogger().setLevel(log_level)

def get_SALT():
    response = boto3.client("secretsmanager").get_secret_value(
        SecretId="SALT"
    )
    secret_string = json.loads(response["SecretString"])
    return secret_string["raw"]

def lambda_function(event, context):
    log.debug("Event: " + json.dumps(event))
    params = json.loads(event["body"])

    username = params["username"]
    password = params["password"]
    token_key = event["stageVariables"]["HK"]
    salt = get_SALT()

    item = table.get_item(ConsistentRead=True, Key={"login": username})
    if item.get('Item') is not None:
        ddb_password = item.get('Item').get('password')
        log.debug("ddb_password:" + json.dumps(ddb_password))

        if ddb_password is not None:
            str2hash = "{}|{}|{}".format(username, password, salt)
            result_hash = hashlib.md5(str2hash.encode()).hexdigest()
            if result_hash == ddb_password:
                issued_at = datetime.today()
                exp_at = issued_at + timedelta(minutes=int(os.getenv("TOKEN_DURATION")))
                payload = {
                    "name": "{} {}".format(item.get('Item').get('name'), item.get('Item').get('surname')),
                    "firstname": str(item.get('Item').get('name')),
                    "surname": str(item.get('Item').get('surname')),
                    "role": str(item.get('Item').get('role')),
                    "code": str(item.get('Item').get('code')),
                    "sub": str(item.get('Item').get('login')),
                    "iat": issued_at.timestamp(),
                    "exp": exp_at.timestamp()
                }
                jwt_token = jwt.encode(payload, token_key, algorithm='HS256').decode()
                refresh_token = jwt.encode(
                    {
                        "sub": "af-api",
                        "iat": issued_at.timestamp(),
                        "exp": exp_at.timestamp()
                    }, 
                    token_key, algorithm='HS256').decode()
                    
                log.debug("JWT token:" + jwt_token)
            else:
                return {
                    "statusCode": 403,
                    "body": json.dumps({
                        "message": "Username and password doesn't match!"
                    })
                }
    
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Login successful",
            "token": jwt_token
        }),
        "headers": {
            "Access-Control-Allow-Origin": "*", 
            "Access-Control-Allow-Credentials": True, 
            "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Set-Cookie": "JWT_TOKEN={}; Path=/; HttpOnly; Secure".format(refresh_token)
        }
    }