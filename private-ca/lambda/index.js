import { signHostSSHCertificate } from './generate-host-ssh-cert.js';
import { signClientSSHCertificate } from './generate-client-ssh-cert.js';
import { getCallerIdentity } from './get-caller-identity.js';
import { generateClientX509Cert } from './generate-client-x509-cert.js';
import { getSecret } from './secret-manager-utils.js';
  
export const handler = async (event) => {
  
  // auth
  const callerIdentity = await getCallerIdentity(event);

  // secret
  const secret = await getSecret(event.awsSecretsRegion, 'privateCA');
  
  // action
  let res = {};
  switch(event.action) {
    case "getHostSSHCert":
      const hostSSHCert = await signHostSSHCertificate(callerIdentity, secret, event.certValidity, event.certPubkey);
      res = {
        statusCode: 200,
        body: JSON.stringify(hostSSHCert)
      }
      return res;
    case "getClientSSHCert":
      const clientSSHCert = await signClientSSHCertificate(callerIdentity, secret, event.certValidity, event.certPubkey);
      console.log(clientSSHCert)
      res = {
        statusCode: 200,
        body: JSON.stringify(clientSSHCert)
      }
      return res;
    case "generateClientX509Cert":
      const res = await generateClientX509Cert(callerIdentity, secret, event);
      return res;
    default:
      console.log("Invalid Action")
      res = {
        statusCode: 400,
        body: JSON.stringify('Invalid Action')
      };
      return res;
  } 
};
