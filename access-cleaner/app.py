import os
from datetime import datetime, timedelta
from pytz import timezone
import logging
import boto3

# Static code used for DynamoDB connection and logging
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.getenv("TABLE_NAME"))
log_level = os.environ['LOG_LEVEL']
log = logging.getLogger(__name__)
logging.getLogger().setLevel(log_level)
SRC_TIMEZONE = timezone("GMT")
DST_TIMEZONE = timezone(os.getenv("TIMEZONE", "Europe/Rome"))

def lambda_function(event, context):
    items = table.scan()
    
    date_tz = SRC_TIMEZONE.localize(datetime.now()).astimezone(DST_TIMEZONE)
    to_remove = []
    for item in items.get("Items",[]):
        checkin = datetime.fromisoformat(item["checkinDate"])
        expired = checkin +  timedelta(days=14)
        if expired < date_tz:
            to_remove.append({"login": item["login"], "checkinDate": item["checkinDate"]})


    with table.batch_writer() as batch:
        for access in to_remove:
            batch.delete_item(
                Key = {
                    "login": access["login"],
                    "checkinDate": access["checkinDate"]
                }
            )

    return "OK"