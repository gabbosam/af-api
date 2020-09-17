import os
import re
import json
from datetime import datetime, timedelta
from pytz import timezone
import logging
import base64
import hashlib
import boto3
from boto3.dynamodb.conditions import Key
import jwt

# Static code used for DynamoDB connection and logging
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])
table_tokens = dynamodb.Table("tokens")
log_level = os.environ['LOG_LEVEL']
log = logging.getLogger(__name__)
logging.getLogger().setLevel(log_level)
SRC_TIMEZONE = timezone("GMT")
DST_TIMEZONE = timezone(os.getenv("TIMEZONE", "Europe/Rome"))

class CheckInNotFound(Exception):
    pass
def lambda_function(event, context):
    log.debug("Event: " + json.dumps(event))
    try:
        params = json.loads(event["body"])
    except TypeError:
        params = event["body"]
    
    if params is None:
        params = {}
    token_key = event["stageVariables"]["HK"]

    authorizationHeader = {k.lower(): v for k, v in event['headers'].items() if k.lower() == 'authorization'}
    token = authorizationHeader["authorization"].split()[1]
    log.debug("JWT Token: {}".format(token))

    jwt_token = jwt.decode(token, token_key, algorithm=['HS256'])

    date_tz = SRC_TIMEZONE.localize(datetime.now()).astimezone(DST_TIMEZONE)
    date = date_tz.isoformat()
    Day = date.split("T")[0]
    Time = date_tz.strftime("%H:%M:%S")

    try:
        try:
            access_hash = jwt_token["access_hash"]
        except KeyError:
            raise CheckInNotFound()
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
                    "checkoutDay": Day,
                    "checkoutDate": date,
                    "checkoutTime": Time,
                    "tenant": jwt_token.get("tenant", "default"),
                    "uuid": jwt_token["uuid"]
                })
                
                del jwt_token["access_hash"]
                token = jwt.encode(jwt_token, token_key, algorithm='HS256').decode()

                with table_tokens.batch_writer() as batch:
                    batch.put_item(
                        {
                            "uuid": jwt_token["uuid"],
                            "token": token
                        }
                    )
    except CheckInNotFound():
        log.error("Ceck-in reference not found")
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
            "message": "Checked out at {}".format(date),
            "token": token
        }),
        "headers": {
            "Access-Control-Allow-Origin": "*", 
            "Access-Control-Allow-Credentials": True, 
            "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "POST, OPTIONS"
        }
    }