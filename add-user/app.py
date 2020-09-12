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

def lambda_function(event, context):
    log.debug("Event: " + json.dumps(event))
    params = json.loads(event["body"])

    salt = os.getenv("SALT")
    str2hash = "{}|{}|{}".format(params["login"], params["password"], salt)
    result_hash = hashlib.md5(str2hash.encode()).hexdigest()
    params["password"] = result_hash

    items = table.scan()
    codes = sorted([int(i["code"]) for i in items.get("Items",[])])
    if codes:
        code = codes[-1] + 1
    else:
        code = 1
    params["code"] = str(code)
    try:
        with table.batch_writer() as batch:
            batch.put_item(params)
    except Exception:
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
            "message": "User added"
        })
    }