import forge from 'node-forge';
import md from 'node-forge';
import { generateRootX509Cert } from './generate-root-x509-cert.js';
import { getSecret } from './secret-manager-utils.js';

export const generateClientX509Cert = async (callerIdentity, secret, sslAttrs) => {

  const pki = forge.pki;

  const arn = callerIdentity.GetCallerIdentityResponse.GetCallerIdentityResult.Arn;
  const roleName = arn.match(/\/([^/]+)$/)?.[1];

  // Load the root certificate private key from a file or string
  const rootKeyPem = Buffer.from(secret.root_ssl_private_key, 'base64').toString('utf-8');
  const rootKey = pki.privateKeyFromPem(rootKeyPem);

  // Load the root certificate public key from a file or string
  let rootCertKey = 'rootX509cert';
  if(!(rootCertKey in secret))
  {
    console.log("No root certificate found. Creating new root certificate.")
    await generateRootX509Cert(secret);
    secret = await getSecret('privateCA');
  }
  let rootCertPem = Buffer.from(secret['rootX509cert'], 'base64').toString('utf-8');
  const rootCert = pki.certificateFromPem(rootCertPem);

  // openssl genrsa -out key.pem 2048
  // openssl rsa -in key.pem -outform PEM -pubout -out public.pem
  const clientPublicKey = pki.publicKeyFromPem(sslAttrs.clientPublicKeyPem);

  // Create a client certificate signing request (CSR)
  const clientCertReq = pki.createCertificationRequest();
  clientCertReq.publicKey = clientPublicKey;
  clientCertReq.setSubject([
    { name: 'countryName', value: 'US' },
    { name: 'localityName', value: 'California' },
    { name: 'organizationName', value: 'Fundwave' },
    { name: 'organizationalUnitName', value: 'Fundwave' },
    { name: 'commonName', value: roleName }
  ]);

  // Sign the client certificate request with the root certificate and private key
  const clientCert = pki.createCertificate();
  clientCert.publicKey = clientCertReq.publicKey;
  clientCert.serialNumber = '01'; // Set a unique serial number

  const startDate = new Date(); // Valid from the current date and time
  const endDate = new Date();
  endDate.setDate(startDate.getDate() + sslAttrs.validityPeriod);
  clientCert.validity.notBefore = startDate;
  clientCert.validity.notAfter = endDate;

  clientCert.setSubject(clientCertReq.subject.attributes);
  clientCert.setIssuer(rootCert.subject.attributes);
  clientCert.setExtensions([
    { name: 'basicConstraints', cA: false },
    { name: 'keyUsage', digitalSignature: true, nonRepudiation: true, keyEncipherment: true },
  ]);
  clientCert.sign(rootKey, md.sha256.create());

  // Convert the signed client certificate to PEM format
  const clientCertPem = pki.certificateToPem(clientCert);
  return clientCertPem;
}