import os
import io
import base64
import qrcode
import logging
import boto3
from botocore.exceptions import ClientError

log_level = os.environ['LOG_LEVEL']
log = logging.getLogger(__name__)
logging.getLogger().setLevel(log_level)

def upload_file(file_obj, bucket, object_name=None):
    """Upload a file to an S3 bucket

    :param file_name: File to upload
    :param bucket: Bucket to upload to
    :param object_name: S3 object name. If not specified then file_name is used
    :return: True if file was uploaded, else False
    """

    # Upload the file
    s3_client = boto3.client('s3')
    try:
        response = s3_client.upload_fileobj(file_obj, bucket, object_name)
    except ClientError as e:
        logging.error(e)
        return False
    return True

def lambda_function(event, context):
    data = event["data"]
    img = qrcode.make(data)
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    buffer.seek(0)
    success = upload_file(buffer, "af-static", "/qrcodes/" + event["file_date"] + ".png")
    return {
        "statusCode": 200 if success else 500,
        "body": success
    }

