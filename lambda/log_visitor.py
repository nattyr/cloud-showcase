import json
import boto3
import os
from datetime import datetime
import pytz

def get_aet_time():
    utc_time = datetime.now(pytz.utc)
    aet = pytz.timezone('Australia/Sydney')
    aet_time = utc_time.astimezone(aet)
    aet_iso = aet_time.isoformat()
    return aet_iso

def hit(event, context):
    ip_address = event['requestContext']['identity']['sourceIp']
    current_aet_datetime = get_aet_time()

    return {
        'statusCode': 200,
        # 'body': '10'
        'body': json.dumps({
            'ip_address': ip_address,
            'current_aet_datetime': current_aet_datetime
        })
    }