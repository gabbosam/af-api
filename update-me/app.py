import os
import re
import json
from decimal import Decimal
import logging
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

def get_SALT():
    response = boto3.client("secretsmanager").get_secret_value(
        SecretId="SALT"
    )
    secret_string = json.loads(response["SecretString"])
    return secret_string["raw"]
    
def lambda_function(event, context):
    log.debug("Event: " + json.dumps(event))
    try:
        params = json.loads(event["body"])
    except TypeError:
        params = event["body"]


    token_key = event["stageVariables"]["HK"]
    authorizationHeader = {k.lower(): v for k, v in event['headers'].items() if k.lower() == 'authorization'}
    token = authorizationHeader["authorization"].split()[1]
    log.debug("JWT Token: {}".format(token))
    jwt_token = jwt.decode(token, token_key, algorithm=['HS256'])
    update_list = []
    update_values = {}
    try:
        if "newpassword" in params:
            salt = get_SALT()
            str2hash = "{}|{}|{}".format(jwt_token["sub"], params["newpassword"], salt)
            result_hash = hashlib.md5(str2hash.encode()).hexdigest()
            update_list.append("password = :pwd")
            update_values[':pwd'] = result_hash
            
        if "privacy" in params:
            update_list.append("privacy = :privacy")
            update_values[":privacy"] = Decimal(params["privacy"])


        for k, v in params.get("profile", {}).items():
            update_list.append("{} = :{}".format(k, k))
            update_values[":{}".format(k)] = v
        
        if update_values:
            item = table.update_item(
                Key={"login": jwt_token["sub"]},
                UpdateExpression='SET ' + ",".join(update_list),
                ExpressionAttributeValues=update_values
            )
        
    except Exception as ex:
        log.error(ex)
        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "Update user failed"
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
            "message":"Update user done!",
            "token": token
        }),
        "headers": {
            "Access-Control-Allow-Origin": "*", 
            "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
        }
    }