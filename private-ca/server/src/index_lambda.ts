import { generateHostSSHCert } from './generate-host-ssh-cert.js';
import { generateClientSSHCert } from './generate-client-ssh-cert.js';
import { getCallerIdentity } from './get-caller-identity.js';
import { getSecret } from './secret-manager-utils.js';
import { 
  LambdaEvent, 
  LambdaResponse, 
} from './types/index.js';

export const handler = async (event: any): Promise<LambdaResponse> => {
  try {
    const parsedEvent: LambdaEvent = JSON.parse(event.body);

    // auth
    const callerIdentity = await getCallerIdentity(parsedEvent);
    const accountId = callerIdentity.GetCallerIdentityResponse.GetCallerIdentityResult.Account;

    // secret
    const secret = await getSecret(accountId);
    if (!secret) {
      return {
        statusCode: 401,
        body: JSON.stringify({ 
          error: 'This AWS account is not configured to use this service'
        }),
      };
    }

    // action
    switch (parsedEvent.action) {
      case "generateHostSSHCert": {
        if (!parsedEvent.certPubkey) {
          return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing certPubkey' }),
          };
        }
        if (!parsedEvent.awsEC2Region) {
          return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing awsEC2Region' }),
          };
        }

        const hostSSHCert = await generateHostSSHCert(
          callerIdentity, 
          secret, 
          parsedEvent.certPubkey, 
          parsedEvent.awsEC2Region
        );
        
        return {
          statusCode: 200,
          body: JSON.stringify({
            certificate: Buffer.from(hostSSHCert).toString('base64'),
            'user_ca.pub': secret['user_ca.pub']
          })
        };
      }
      
      case "generateClientSSHCert": {
        if (!parsedEvent.certPubkey) {
          return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing certPubkey' }),
          };
        }
        const clientSSHCert = await generateClientSSHCert(
          callerIdentity, 
          secret, 
          parsedEvent.certPubkey
        );
        
        return {
          statusCode: 200,
          body: JSON.stringify({
            certificate: Buffer.from(clientSSHCert).toString('base64'),
            'host_ca.pub': secret['host_ca.pub']
          })
        };
      }

      case "getHostCAPublicKey": {
        return {
          statusCode: 200,
          body: JSON.stringify({ 'host_ca.pub': secret['host_ca.pub'] })
        };
      }
      
      default:
        console.log(`Invalid Action: ${parsedEvent.action}`, { event: parsedEvent });
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'Invalid Action' }),
        };
    }
  } catch (err) {
    console.error('Error in cert signing handler:', err);
    const errorMessage = err instanceof Error ? err.message : 'Internal server error';
    return {
      statusCode: 500,
      body: JSON.stringify({ error: errorMessage }),
    };
  }
}; 