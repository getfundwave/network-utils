import fs from 'fs';
import child_process from 'child_process';
import util from 'util';
import { format } from 'date-fns';
import { CallerIdentityResponse, SecretData } from './types/index.js';

const exec = util.promisify(child_process.exec);
const clientCertValidityInDays = parseInt(process.env.clientCertValidityInDays ?? '1', 10);
const caKeyPath = "/tmp/client_ca";
const publicKeyName = "ssh_client_rsa_key";
const publicKeyPath = "/tmp/" + publicKeyName + ".pub";
const certificatePath = "/tmp/" + publicKeyName + "-cert.pub";

export const generateClientSSHCert = async (
  callerIdentity: CallerIdentityResponse, 
  secret: SecretData, 
  certPubkey: string
): Promise<string> => {
  const arn = callerIdentity.GetCallerIdentityResponse.GetCallerIdentityResult.Arn;
  const match = arn.match(/\/([^/]+)$/);
  if (!match) {
    throw new Error(`Invalid ARN format: ${arn}`);
  }
  const principal = match[1];
  const user_ca = Buffer.from(secret.user_ca, 'base64').toString('utf-8');

  const decodedCertPubkey = Buffer.from(certPubkey, 'base64').toString('utf-8');
  fs.writeFileSync(caKeyPath, user_ca);
  fs.writeFileSync(publicKeyPath, decodedCertPubkey);
  
  let result = await exec(`chmod 600 ${caKeyPath}`);
  console.log('stdout:', result.stdout);
  console.log('stderr:', result.stderr);

  const now = new Date();
  const validFrom = format(now, "yyyyMMddHHmmss");
  
  const validUntil = new Date(now.getTime() + (clientCertValidityInDays * 24 * 60 * 60 * 1000));
  const validTo = format(validUntil, "yyyyMMddHHmmss");

  const validityPeriod = `${validFrom}:${validTo}`;

  result = await exec(
    `ssh-keygen -s ${caKeyPath} -t rsa-sha2-512 -I client_${principal} -n ${principal} -V ${validityPeriod} ${publicKeyPath}`
  );

  console.log('stdout:', result.stdout);
  console.log('stderr:', result.stderr);

  const certificate = fs.readFileSync(certificatePath, 'utf8');
  return certificate;
}; 