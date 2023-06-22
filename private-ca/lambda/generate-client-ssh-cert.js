import fs from 'fs';
import child_process from 'child_process';
import util from 'util';

const exec = util.promisify(child_process.exec);

export const signClientSSHCertificate = async (callerIdentity, secret, sshAttrs) => {

  const arn = callerIdentity.GetCallerIdentityResponse.GetCallerIdentityResult.Arn;
  const roleName = arn.match(/\/([^/]+)$/)?.[1];
  
  const caKeyPath = "/tmp/client_ca";
  const publicKeyName = "ssh_client_rsa_key";
  const publicKeyPath = "/tmp/" + publicKeyName + ".pub";
  const certificatePath = "/tmp/" + publicKeyName + "-cert.pub";
  const user_ca = Buffer.from(secret.user_ca, 'base64').toString('utf-8');
  fs.writeFileSync(caKeyPath, user_ca);
  fs.writeFileSync(publicKeyPath, sshAttrs['sshClientRSAKey']);
  
  let { stdout, stderr } = await exec(`chmod 600 ${caKeyPath}`);
  console.log('stdout:', stdout);
  console.log('stderr:', stderr);

  ({ stdout, stderr } = await exec(`ssh-keygen -s ${caKeyPath} -I host_${roleName} -n ${roleName} -V +${sshAttrs['validity']} ${publicKeyPath}`));
  console.log('stdout:', stdout);
  console.log('stderr:', stderr);

  const certificate = fs.readFileSync(certificatePath, 'utf8');
  return certificate;
};