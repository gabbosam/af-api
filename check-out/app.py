import os
import re
import json
from datetime import datetime, timedelta
import logging
import base64
import hashlib
import boto3
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
    params = json.loads(event["body"])
    salt = os.getenv("HK")

    authorizationHeader = {k.lower(): v for k, v in event['headers'].items() if k.lower() == 'authorization'}
    token = authorizationHeader["authorization"].split()[1]
    log.debug("JWT Token: {}".format(token))
    try:
        jwt_token = jwt.decode(token, salt, algorithm=['HS256'])
    except jwt.ExpiredSignatureError as ex:
        return {
            "statusCode": 401,
            "body": "Token expired!"
        }
        
    checkout_date = "{} {}".format(params["checkoutDay"], params["checkoutTime"])
    access_hash = jwt_token["access_hash"]
    try:
        with table.batch_writer() as batch:
            items = table.query(
                IndexName="login-hash-index",
                KeyConditionExpression=(Key("login").eq(jwt_token["sub"]) & Key("hash").eq(access_hash))
            )
            
            item = items.get("Items",[]) and items.get("Items")[0]
            if item:
                batch.put_item({
                    "login": jwt_token["sub"],
                    "name": jwt_token["name"],
                    "checkinDate": item["checkinDate"],
                    "checkinDay": item["checkinDay"],
                    "checkinTime": item["checkinTime"],
                    "bodyTemp": "n/a",
                    "checkoutDay": params["checkoutDay"],
                    "checkoutDate": checkout_date,
                    "checkoutTime": params["checkoutTime"]
                })
                
                del jwt_token["access_hash"]
                token = jwt.encode(jwt_token, salt, algorithm='HS256').decode()
            else:
                return {
                    "statusCode": 404,
                    "body": json.dumps({
                        "message": "Check-in reference not found"
                    })
                }
    except Exception as ex:
        log.error(ex)
        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "Checkout failed"
            })
        }

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Checked out at {}".format(checkout_date),
            "token": token
        })
    }