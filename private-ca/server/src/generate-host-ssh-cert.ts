import fs from 'fs';
import child_process from 'child_process';
import util from 'util';
import { getPublicIpAddress } from './get-public-ip-address.js';
import { format } from 'date-fns';
import { CallerIdentityResponse, SecretData } from './types/index.js';

const exec = util.promisify(child_process.exec);
const hostCertValidityInDays = parseInt(process.env.hostCertValidityInDays ?? '7', 10);

export const generateHostSSHCert = async (
  callerIdentity: CallerIdentityResponse, 
  secret: SecretData, 
  certPubkey: string, 
  awsEC2Region: string
): Promise<string> => {
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
  const decodedCertPubkey = Buffer.from(certPubkey, 'base64').toString('utf-8');
  
  fs.writeFileSync(caKeyPath, host_ca);
  fs.writeFileSync(publicKeyPath, decodedCertPubkey);

  let result = await exec(`chmod 600 ${caKeyPath}`);
  console.log('stdout:', result.stdout);
  console.log('stderr:', result.stderr);

  const now = new Date();
  const validFrom = format(now, "yyyyMMddHHmmss");
  
  const validUntil = new Date(now.getTime() + (hostCertValidityInDays * 24 * 60 * 60 * 1000));
  const validTo = format(validUntil, "yyyyMMddHHmmss");

  const validityPeriod = `${validFrom}:${validTo}`;

  result = await exec(
    `ssh-keygen -s ${caKeyPath} -t rsa-sha2-512 -I host_${instanceId} -h -n ${publicIp} -V ${validityPeriod} ${publicKeyPath}`
  );
  
  console.log('stdout:', result.stdout);
  console.log('stderr:', result.stderr);

  const certificate = fs.readFileSync(certificatePath, 'utf8');
  return certificate;
}; 