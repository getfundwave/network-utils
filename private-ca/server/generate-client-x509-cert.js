import forge from 'node-forge';
import md from 'node-forge';
import crypto from "crypto";

const countryName = process.env.countryName ?? "SG";
const localityName =  process.env.localityName ?? "Singapore";
const organizationName =  process.env.organizationName ?? "Fundwave";
const organizationalUnitName = process.env.localityName ?? "Fundwave";

const validityInDays = process.env.validityInDays ?? 1;
const messageDigestAlg = process.env.messageDigestAlg ?? "sha256";

export const generateClientX509Cert = async (callerIdentity, secret, event) => {

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
    console.log("No root certificate found. Aborting creation of client X.509 certificate.");
    return {
      statusCode: 500,
      body: "No root certificate found."
    };
  }
  let rootCertPem = Buffer.from(secret['rootX509cert'], 'base64').toString('utf-8');
  const rootCert = pki.certificateFromPem(rootCertPem);

  // openssl genrsa -out key.pem 2048
  // openssl rsa -in key.pem -outform PEM -pubout -out public.pem
  const clientPublicKey = pki.publicKeyFromPem(Buffer.from(event.certPubkey, 'base64').toString('utf-8'));

  // Create a client certificate signing request (CSR)
  const clientCertReq = pki.createCertificationRequest();
  clientCertReq.publicKey = clientPublicKey;
  clientCertReq.setSubject([
    { name: 'countryName', value: countryName },
    { name: 'localityName', value: localityName },
    { name: 'organizationName', value: organizationName },
    { name: 'organizationalUnitName', value: organizationalUnitName },
    { name: 'commonName', value: roleName }
  ]);

  // Sign the client certificate request with the root certificate and private key
  const clientCert = pki.createCertificate();
  clientCert.publicKey = clientCertReq.publicKey;
  // clientCert.serialNumber = crypto.randomBytes(8).toString("hex"); // Set a unique serial number upto 20 bytes. https://security.stackexchange.com/questions/35691/what-is-the-difference-between-serial-number-and-thumbprint https://www.hindawi.com/journals/scn/2019/6013846/

  clientCert.setSubject(clientCertReq.subject.attributes);
  clientCert.setIssuer(rootCert.subject.attributes);
  clientCert.setExtensions([
    { name: 'basicConstraints', cA: false },
    { name: 'keyUsage', digitalSignature: true, nonRepudiation: true, keyEncipherment: true },
  ]);

  const startDate = new Date(); // Valid from the current date and time
  const endDate = new Date();
  endDate.setDate(startDate.getDate() + validityInDays);
  clientCert.validity.notBefore = startDate;
  clientCert.validity.notAfter = endDate;

  clientCert.sign(rootKey, md[messageDigestAlg].create());

  // Convert the signed client certificate to PEM format
  const clientCertPem = pki.certificateToPem(clientCert);
  return {
    statusCode: 200,
    body: Buffer.from(clientCertPem).toString('base64')
  };
  
}