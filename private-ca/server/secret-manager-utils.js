import aws from "aws-sdk";

export const getSecret = async (secretRegion, secretId) => {
  var secretsmanager = new aws.SecretsManager({ region: secretRegion });
  const secretString = await secretsmanager.getSecretValue({ SecretId: secretId }).promise();
  const secret = JSON.parse(secretString.SecretString);
  return secret;
};

/**
export const updateSecret = async (secretRegion, secretId, key, value) => {
  var secretsmanager = new aws.SecretsManager({ region: secretRegion });
  let secret = await getSecret(secretId);
  secret[key] = value;
  var params = {
    SecretId: secretId, 
    SecretString: JSON.stringify(secret)
  };
  const updateRes = await secretsmanager.updateSecret(params).promise();
  return updateRes;
}
**/
