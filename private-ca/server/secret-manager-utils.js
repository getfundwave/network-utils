import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

export const getSecret = async (secretRegion, secretId) => {
  const client = new SecretsManagerClient({ region: secretRegion });
  const command = new GetSecretValueCommand({ SecretId: secretId });
  const response = await client.send(command);
  const secret = JSON.parse(response.SecretString);
  return secret;
}