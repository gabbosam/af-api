import os
import re
import json
import logging
import hashlib
import boto3

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

    salt = get_SALT()
    items = table.scan()

    for i, item in enumerate(params):
        pwd = item.get("password", item["name"].lower())
        str2hash = "{}|{}|{}".format(item["login"], pwd, salt)
        result_hash = hashlib.md5(str2hash.encode()).hexdigest()
        item["password"] = result_hash

        if not item.get("code"):
            codes = sorted([int(i["code"]) for i in items.get("Items",[])])
            if codes:
                code = codes[-1] + (i+1)
            else:
                code = 1
            item["code"] = str(code)
            
        if "tenant" not in item:
            item["tenant"] = "default"
            
        try:
            with table.batch_writer() as batch:
                batch.put_item(item)
        except Exception:
            log.error("error processi item: {}".format(item))
            import traceback
            traceback.print_exc()
            return {
                "statusCode": 500,
                "body": json.dumps({
                    "message": "Error"
                })
            }
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Users added"
        })
    }