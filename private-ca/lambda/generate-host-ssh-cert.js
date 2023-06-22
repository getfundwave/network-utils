import fs from 'fs';
import child_process from 'child_process';
import util from 'util';

const exec = util.promisify(child_process.exec);

export const signHostSSHCertificate = async (callerIdentity, secret, sshAttrs) => {

  const arn = callerIdentity.GetCallerIdentityResponse.GetCallerIdentityResult.Arn;
  const roleName = arn.match(/\/([^/]+)$/)?.[1];
  
  const caKeyPath = "/tmp/host_ca";
  const publicKeyName = "ssh_host_rsa_key";
  const publicKeyPath = "/tmp/" + publicKeyName + ".pub";
  const certificatePath = "/tmp/" + publicKeyName + "-cert.pub";
  const host_ca = Buffer.from(secret.host_ca, 'base64').toString('utf-8');
  fs.writeFileSync(caKeyPath, host_ca);
  fs.writeFileSync(publicKeyPath, sshAttrs['sshHostRSAKey']);

  let { stdout, stderr } = await exec(`chmod 600 ${caKeyPath}`);
  console.log('stdout:', stdout);
  console.log('stderr:', stderr);

  ({ stdout, stderr } = await exec(`ssh-keygen -s ${caKeyPath} -I host_${roleName} -h -n ${roleName} -V +${sshAttrs['validity']} ${publicKeyPath}`));
  console.log('stdout:', stdout);
  console.log('stderr:', stderr);

  const certificate = fs.readFileSync(certificatePath, 'utf8');
  return certificate;
};