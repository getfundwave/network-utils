import aws from "aws-sdk";

var secretsmanager = new aws.SecretsManager({ region: 'ap-south-1' });

export const getSecret = async (secretId) => {
  const secretString = await secretsmanager.getSecretValue({ SecretId: secretId }).promise();
  const secret = JSON.parse(secretString.SecretString);
  return secret;
};

export const updateSecret = async (secretId, key, value) => {
  let secret = await getSecret(secretId);
  secret[key] = value;
  var params = {
    SecretId: secretId, 
    SecretString: JSON.stringify(secret)
  };
  const updateRes = await secretsmanager.updateSecret(params).promise();
  return updateRes;
}
