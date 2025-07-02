import fs from 'fs';
import child_process from 'child_process';
import util from 'util';
import { getPublicIpAddress } from './get-public-ip-address.js';
import formatDate from './format-date.js';

const exec = util.promisify(child_process.exec);
const validityInDays = process.env.validityInDays ?? 1;

export const signHostSSHCertificate = async (callerIdentity, secret, certPubkey, awsEC2Region) => {

  const arn = callerIdentity.GetCallerIdentityResponse.GetCallerIdentityResult.Arn;
  const match = arn.match(/\/([^/]+)$/);
  if (!match) {
      throw new Error(`Invalid ARN format: ${arn}`);
  }
  const instanceId = match[1];

  const publicIp = await getPublicIpAddress(awsEC2Region, instanceId);

  const caKeyPath = "/tmp/host_ca";
  const publicKeyName = "ssh_host_rsa_key";
  const publicKeyPath = "/tmp/" + publicKeyName + ".pub";
  const certificatePath = "/tmp/" + publicKeyName + "-cert.pub";
  const host_ca = Buffer.from(secret.host_ca, 'base64').toString('utf-8');
  certPubkey = Buffer.from(certPubkey, 'base64').toString('utf-8');
  fs.writeFileSync(caKeyPath, host_ca);
  fs.writeFileSync(publicKeyPath, certPubkey);

  let { stdout, stderr } = await exec(`chmod 600 ${caKeyPath}`);
  console.log('stdout:', stdout);
  console.log('stderr:', stderr);

  const now = new Date();
  const validFrom = formatDate(now);
  
  const validUntil = new Date(now.getTime() + (validityInDays * 24 * 60 * 60 * 1000));
  const validTo = formatDate(validUntil);

  const validityPeriod = `${validFrom}:${validTo}`;

  (
    { stdout, stderr } = await exec(
      `ssh-keygen -s ${caKeyPath} -t rsa-sha2-512 -I host_${instanceId} -h -n ${publicIp} -V ${validityPeriod} ${publicKeyPath}`
    )
  );
  
  console.log('stdout:', stdout);
  console.log('stderr:', stderr);

  const certificate = fs.readFileSync(certificatePath, 'utf8');
  return certificate;
};
