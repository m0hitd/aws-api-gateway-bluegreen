import json

def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({
            'version': 'v2.0.0',
            'environment': 'green',
            'message': 'New release candidate',
            'new_feature': 'enhanced_response'
        })
    }
