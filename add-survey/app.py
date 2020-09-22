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
table_users = dynamodb.Table("users")
table_tokens = dynamodb.Table("tokens")
log_level = os.environ['LOG_LEVEL']
log = logging.getLogger(__name__)
logging.getLogger().setLevel(log_level)
SRC_TIMEZONE = timezone("GMT")
DST_TIMEZONE = timezone(os.getenv("TIMEZONE", "Europe/Rome"))

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
    Day = date_tz.strftime("%d/%m/%Y")

    update_params = {
        k: "Si" if v else "No"
        for k,v in params.items()
    }

    update_params["login"] = jwt_token["sub"]
    update_params["dateSubmit"] = Day

    try:
        with table.batch_writer() as batch:
            # put survey data
            batch.put_item(update_params)
        # update users with last submit date
        table_users.update_item(
            Key={"login": jwt_token["sub"]},
            UpdateExpression='SET date_submit_survey = :date_submit_survey',
            ExpressionAttributeValues={
                ":date_submit_survey": Day
            }
        )

        jwt_token["date_submit_survey"] = Day
        token = jwt.encode(jwt_token, token_key, algorithm='HS256').decode()

        with table_tokens.batch_writer() as batch:
            batch.put_item(
                {
                    "uuid": jwt_token["uuid"],
                    "token": token
                }
            )

    except Exception as ex:
        import traceback
        traceback.print_exc()
        log.error(ex)
        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "Survey failed"
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
            "message":"Survey saved at {}".format(date),
            "token": token
        }),
        "headers": {
            "Access-Control-Allow-Origin": "*", 
            "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
        }
    }