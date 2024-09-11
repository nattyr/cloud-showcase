import boto3
import os
import dateutil.tz
import json
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
log_table_name = os.environ.get('LOG_TABLE_NAME')
count_table_name = os.environ.get('COUNT_TABLE_NAME')

def log_hit(ip, log_datetime):
    try:
        table = dynamodb.Table(log_table_name)
        response = table.put_item(
            Item={
                'IPAddress': ip,
                'DateTime': log_datetime
            }
        )
        return response
    
    except Exception as e:
        print(f"Error logging hit: {e}")
        return None
    
def increment_hit_counter():
    try:
        table = dynamodb.Table(count_table_name)
        
        # Todo: implement dynamicaly fetched page title
        page_name = "home"
        
        # If the record does not exist, update_item will create it
        update_response = table.update_item(
            Key={'PageName': page_name},
            UpdateExpression='SET #count = if_not_exists(#count, :start) + :increment',
            ExpressionAttributeNames={'#count': 'count'},
            ExpressionAttributeValues={
                ':start': 0,
                ':increment': 1
                },
            ReturnValues='ALL_NEW'
        )

        return update_response
    
    except Exception as e:
        print(f"Error incrementing hit counter: {e}")
        return None

def hit(event, context):
    try:
        # Get source IP address
        ip_address = event['requestContext']['identity']['sourceIp']
        
        # Get current time in AET
        aet = dateutil.tz.gettz('Australia/Sydney')
        current_datetime_aet = datetime.now(tz=aet).isoformat()
        
        log_response = log_hit(ip_address, current_datetime_aet)
        increment_response = increment_hit_counter()

        # Get hit count
        count = "0"
        if 'Attributes' in increment_response:
                count = increment_response.get('Attributes').get('count')

        return {
            'statusCode': 200,
            'body': json.dumps({'count': str(count)})
        }
    
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal Server Error'})
        }