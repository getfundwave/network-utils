import { signHostSSHCertificate } from './generate-host-ssh-cert.js';
import { signClientSSHCertificate } from './generate-client-ssh-cert.js';
import { getCallerIdentity } from './get-caller-identity.js';
import { generateClientX509Cert } from './generate-client-x509-cert.js';
import { getSecret } from './secret-manager-utils.js';
  
export const handler = async (event) => {
  
  // auth
  const callerIdentity = await getCallerIdentity(event);

  // secret
  const secret = await getSecret(event.awsSecretsRegion, 'private_CA_Secret');
  
  // action
  switch(event.action) {
    case "generateHostSSHCert":
      const hostSSHCert = await signHostSSHCertificate(callerIdentity, secret, event.certValidity, event.certPubkey);
      return {
        statusCode: 200,
        body: JSON.stringify(hostSSHCert)
      };
    case "generateClientSSHCert":
      const clientSSHCert = await signClientSSHCertificate(callerIdentity, secret, event.certValidity, event.certPubkey);
      return {
        statusCode: 200,
        body: JSON.stringify(clientSSHCert)
      };
    case "generateClientX509Cert":
      return await generateClientX509Cert(callerIdentity, secret, event);
    default:
      console.log("Invalid Action")
      return {
        statusCode: 400,
        body: JSON.stringify('Invalid Action')
      };
  } 
};
