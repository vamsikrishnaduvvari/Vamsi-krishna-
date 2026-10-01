import json
import logging
import urllib.parse

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """Record each S3 object-created event in CloudWatch Logs."""
    for record in event.get("Records", []):
        s3 = record["s3"]
        bucket = s3["bucket"]["name"]
        key = urllib.parse.unquote_plus(s3["object"]["key"])
        logger.info(json.dumps({"bucket": bucket, "key": key, "event": record["eventName"]}))
    return {"statusCode": 200, "processed": len(event.get("Records", []))}
