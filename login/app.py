import os
import re
import json
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

def lambda_function(event, context):
    log.debug("Event: " + json.dumps(event))
    params = json.loads(event["body"])

    username = params["username"]
    password = params["password"]
    salt = os.getenv("HK")

    item = table.get_item(ConsistentRead=True, Key={"login": username})
    if item.get('Item') is not None:
        ddb_password = item.get('Item').get('password')
        log.debug("ddb_password:" + json.dumps(ddb_password))

        if ddb_password is not None:
            str2hash = "{}|{}|{}".format(username, password, os.getenv("HK"))
            result_hash = hashlib.md5(str2hash.encode()).hexdigest()
            if result_hash == ddb_password:
                payload = {
                    "name": str(item.get('Item').get('name')),
                    "surname": str(item.get('Item').get('surname')),
                    "role": str(item.get('Item').get('role')),
                    "code": str(item.get('Item').get('code')),
                    "login": str(item.get('Item').get('login'))
                }
                jwt_token = jwt.encode(payload, salt, algorithm='HS256').decode()
                log.debug("JWT token:" + jwt_token)
            else:
                return {
                    "statusCode": 403,
                    "body": {
                        "message": "Username and password doesn't match!"
                    }
                }
    
    return {
        "statusCode": 200,
        "body": json.dumps({
            "token": jwt_token
        })
    }