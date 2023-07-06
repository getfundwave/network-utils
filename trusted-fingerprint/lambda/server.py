import paramiko

def lambda_handler(event, context):
    
    try:
        host = event['url']
        key_type = event['keyType']
        
        transport = paramiko.Transport(host)
        transport.get_security_options().key_types = [key_type]
        transport.connect()
        
        key = transport.get_remote_server_key()
        key_body = key.get_base64()
        
        transport.close()

        return {
            'statusCode': 200,
            'keyBody': key_body
        }
    except:
        return {
            'statusCode': 500,
            'body': 'Internal Server Error'
        }
