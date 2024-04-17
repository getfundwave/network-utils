const jwkToPem = require("jwk-to-pem");
const JwksError = require("./errors/JwksError");

function resolveAlg(jwk) {
  if (jwk.alg) {
    return jwk.alg;
  }

  if (jwk.kty === "RSA") {
    return "RS256";
  }

  if (jwk.kty === "EC") {
    switch (jwk.crv) {
      case "P-256":
        return "ES256";
      case "P-384":
        return "ES384";
      case "P-521":
        return "ES512";
    }
  }

  throw new JwksError(`Unsupported JWK`);
}

async function retrieveSigningKey(jwk) {
  let result = {};
  try {
    const alg = resolveAlg(jwk);
    const key = await jwkToPem(jwk);
    result = {
      publicKey: key,
      ...(typeof jwk.kid === "string" && jwk.kid
        ? { kid: jwk.kid }
        : undefined),
      alg,
    };
  } catch (err) {
    throw err;
  }

  return result;
}

module.exports = {
  retrieveSigningKey,
};
