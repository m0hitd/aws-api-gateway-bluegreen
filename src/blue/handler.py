import json

def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({
            'version': 'v1.0.0',
            'environment': 'blue',
            'message': 'Stable production release'
        })
    }
