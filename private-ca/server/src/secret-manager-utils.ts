import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
import { SecretData } from './types/index.js';

export const getSecret = async (
  accountId: string
): Promise<SecretData | null> => {
  const client = new SecretsManagerClient();
  try {
    const command = new GetSecretValueCommand({ 
      SecretId: `privateCA_${accountId}_secret` 
    });
    const response = await client.send(command);
    
    if (!response.SecretString) {
      return null;
    }
    
    const secret = JSON.parse(response.SecretString) as SecretData;
    return secret;
  } catch (err) {
    console.error(`Failed to retrieve secret for account ${accountId} from AWS Secrets Manager:`, err);
    return null;
  }
};