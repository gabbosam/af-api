import os
import re
import json
from datetime import datetime, timedelta
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
            "body": json.dumps({
                "message": "Token expired!"
            })
        }
    
    access_hash = jwt_token.get("access_hash","")
    log.debug("Access hash: {}".format(access_hash))
    if access_hash:
        items = table.query(
            IndexName = "login-hash-index",
            KeyConditionExpression=(Key("login").eq(jwt_token["sub"]) & Key("hash").eq(access_hash))
        )
        if len(items.get("Items", [])):
            return {
                "statusCode": 200,
                "body": json.dumps({
                    "message": "Check-in already exists"
                })
            }
            
    checkin_date = "{} {}".format(params["checkinDay"], params["checkinTime"])
    try:
        with table.batch_writer() as batch:
            access_hash = hashlib.md5("{}|{}".format(jwt_token["sub"],checkin_date).encode()).hexdigest()
            batch.put_item({
                "login": jwt_token["sub"],
                "name": jwt_token["name"],
                "checkinDate": checkin_date,
                "checkinDay": params["checkinDay"],
                "checkinTime": params["checkinTime"],
                "bodyTemp": "n/a",
                "checkoutDay": "",
                "checkoutDate": "",
                "checkoutTime": "",
                "hash": access_hash
            })
            jwt_token["access_hash"] = access_hash
            token = jwt.encode(jwt_token, salt, algorithm='HS256').decode()
    except Exception as ex:
        log.error(ex)
        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "Checkin failed"
            })
        }

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message":"Checked in at {}".format(checkin_date),
            "token": token
        })
    }