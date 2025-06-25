import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

export const getSecret = async (secretRegion, secretPrefix, accountId) => {
  const client = new SecretsManagerClient({ region: secretRegion });
  try {
    const command = new GetSecretValueCommand({ SecretId: `${secretPrefix}_${accountId}_secret` });
    const response = await client.send(command);
    const secret = JSON.parse(response.SecretString);
    return secret;
  } catch (err) {
    console.log(err);
    return null;
  }
}