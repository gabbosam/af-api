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

def lambda_function(event, context):
    log.debug("Event: " + json.dumps(event))
    params = json.loads(event["body"])
    salt = os.getenv("HK")

    authorizationHeader = {k.lower(): v for k, v in event['headers'].items() if k.lower() == 'authorization'}
    token = authorizationHeader["authorization"].split()[1]
    log.debug("JWT Token: {}".format(token))
    jwt_token = jwt.decode(token, salt, algorithm=['HS256'])

    checkin_date = "{} {}".format(params["checkinDay"], params["checkinTime"])
    try:
        with table.batch_writer() as batch:
            batch.put_item({
                "login": jwt_token["sub"],
                "name": jwt_token["name"],
                "checkinDate": checkin_date,
                "checkinDay": params["checkinDay"],
                "checkinTime": params["checkinTime"],
                "bodyTemp": "n/a",
                "checkoutDay": "",
                "checkoutDate": "",
                "checkoutTime": ""
            })
    except Exception as ex:
        return {
            "statusCode": 500,
            "body": "Checkin failed"
        }

    return {
        "statusCode": 200,
        "body": "Checked in at {}".format(checkin_date)
    }