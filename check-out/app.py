import os
import re
import json
from datetime import datetime, timedelta
from pytz import timezone
import logging
import base64
import hashlib
import boto3
from boto3.dynamodb.conditions import Key, Attr
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

    items = []

    try:
        access_hash = params.get("access_hash")
        if not access_hash:
            item = table_tokens.get_item(ConsistentRead=True, Key={"uuid": jwt_token["uuid"]})
            if item.get('Item') is not None:
                token = item.get('Item').get("token")
                try:
                    payload = jwt.decode(token, token_key, algorithm=['HS256'], verify=False)
                    access_hash = payload["access_hash"]
                    items = table.query(
                        IndexName="login-hash-index",
                        KeyConditionExpression=(Key("login").eq(jwt_token["sub"]) & Key("hash").eq(access_hash))
                    )
                except Exception as err:
                    log.error(err)
                    raise CheckInNotFound()
        if not items:
            items = table.scan(
                FilterExpression = Attr('login').eq(jwt_token["sub"]) & Attr("checkinDay").eq(Day) & Attr("checkoutDay").eq("")
            )
                

        with table.batch_writer() as batch:
            for item in items.get("Items",[]):
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
                    "uuid": item["uuid"],
                })
                
                jwt_token["last_checkout"] = "{} {}".format(date_tz.strftime("%d/%m/%Y"), Time)
                del jwt_token["access_hash"]
                token = jwt.encode(jwt_token, token_key, algorithm='HS256').decode()

                with table_tokens.batch_writer() as batch:
                    batch.put_item(
                        {
                            "uuid": jwt_token["uuid"],
                            "token": token
                        }
                    )
    except CheckInNotFound:
        log.error("Check-in reference not found")
        return {
            "statusCode": 404,
            "body": json.dumps({
                "message": "Check-in reference not found"
            }),
            "headers": {
                "Access-Control-Allow-Origin": "*", 
                "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            }
        }
    except Exception as ex:
        log.error(ex)
        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "Checkout failed"
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
            "message": "Checked out at {}".format(date),
            "token": token
        }),
        "headers": {
            "Access-Control-Allow-Origin": "*", 
            "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
        }
    }