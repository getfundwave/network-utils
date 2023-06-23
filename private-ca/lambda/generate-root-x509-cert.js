import forge from 'node-forge';
import { updateSecret } from './secret-manager-utils.js';

export const generateRootX509Cert = async (secret, event) => {

  let publicKeyPem = Buffer.from(secret.root_ssl_public_key, 'base64').toString('utf-8');
  let publicKey = forge.pki.publicKeyFromPem(publicKeyPem);
  let privateKeyPem = Buffer.from(secret.root_ssl_private_key, 'base64').toString('utf-8');
  let privateKey = forge.pki.privateKeyFromPem(privateKeyPem);

  let cert = forge.pki.createCertificate();
  cert.publicKey = publicKey;
  cert.serialNumber = '01';
  cert.validity.notBefore = new Date();
  cert.validity.notAfter = new Date();
  cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 1);
  let attrs = [
    { name: 'countryName', value: 'US' },
    { name: 'localityName', value: 'California' },
    { name: 'organizationName', value: 'Fundwave' },
    { name: 'organizationalUnitName', value: 'Fundwave' },
    { name: 'commonName', value: 'FundwaveCA' }
  ];
  cert.setSubject(attrs);
  cert.setIssuer(attrs);
  cert.setExtensions([{
    name: 'basicConstraints',
    cA: true
  }]);

  cert.sign(privateKey, forge.md.sha256.create());

  let rootX509Cert = forge.pki.certificateToPem(cert);
  await updateSecret(event.awsSecretsRegion, 'privateCA', 'rootX509cert', Buffer.from(rootX509Cert).toString('base64'));

}