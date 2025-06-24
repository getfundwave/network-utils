import { signHostSSHCertificate } from './generate-host-ssh-cert.js';
import { signClientSSHCertificate } from './generate-client-ssh-cert.js';
import { getCallerIdentity } from './get-caller-identity.js';
import { getSecret } from './secret-manager-utils.js';

const AWS_SECRETS_REGION = process.env.AWS_SECRETS_REGION;

export const handler = async (event) => {
  try {
    event = JSON.parse(event.body);

    if (!event.certPubkey) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Missing certPubkey' }),
      };
    }

    // auth
    const callerIdentity = await getCallerIdentity(event);

    // secret
    const secret = await getSecret(AWS_SECRETS_REGION, 'privateCA');

    // action
    switch (event.action) {
      case "generateHostSSHCert":
        if (!event.awsEC2Region) {
          return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing awsEC2Region' }),
          };
        }

        const hostSSHCert = await signHostSSHCertificate(callerIdentity, secret, event.certPubkey, event.awsEC2Region);
        return {
          statusCode: 200,
          body: "{\"certificate\" : \""+Buffer.from(hostSSHCert).toString('base64')+"\", \"user_ca.pub\": \""+secret["user_ca.pub"]+"\"}"
        };
      case "generateClientSSHCert":
        const clientSSHCert = await signClientSSHCertificate(callerIdentity, secret, event.certPubkey);
        return {
          statusCode: 200,
          body: "{\"certificate\" : \""+Buffer.from(clientSSHCert).toString('base64')+"\", \"host_ca.pub\": \""+secret["host_ca.pub"]+"\"}"
        };
      default:
        console.log("Invalid Action")
        return {
          statusCode: 400,
          body: JSON.stringify({ error: 'Invalid Action' }),
        };
    }
  } catch (err) {
    console.error('Error in cert signing handler:', err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};