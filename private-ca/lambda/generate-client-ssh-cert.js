import fs from 'fs';
import child_process from 'child_process';
import util from 'util';

const exec = util.promisify(child_process.exec);

export const signClientSSHCertificate = async (callerIdentity, secret, certPubkey) => {

  const arn = callerIdentity.GetCallerIdentityResponse.GetCallerIdentityResult.Arn;
  const roleName = arn.match(/\/([^/]+)$/)?.[1];
  
  const caKeyPath = "/tmp/client_ca";
  const publicKeyName = "ssh_client_rsa_key";
  const publicKeyPath = "/tmp/" + publicKeyName + ".pub";
  const certificatePath = "/tmp/" + publicKeyName + "-cert.pub";
  const user_ca = Buffer.from(secret.user_ca, 'base64').toString('utf-8');
  certPubkey = Buffer.from(certPubkey, 'base64').toString('utf-8');
  fs.writeFileSync(caKeyPath, user_ca);
  fs.writeFileSync(publicKeyPath, certPubkey);
  
  let { stdout, stderr } = await exec(`chmod 600 ${caKeyPath}`);
  console.log('stdout:', stdout);
  console.log('stderr:', stderr);

  ({ stdout, stderr } = await exec(`ssh-keygen -s ${caKeyPath} -I client_${roleName} -n ${roleName} -V +1d ${publicKeyPath}`));
  console.log('stdout:', stdout);
  console.log('stderr:', stderr);

  const certificate = fs.readFileSync(certificatePath, 'utf8');
  return certificate;
};
