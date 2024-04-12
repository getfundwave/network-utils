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

  throw new JwksError("Unsupported JWK");
}

async function retrieveSigningKeys(jwks) {
  const results = [];

  jwks = jwks
    .filter(({ use }) => use === "sig" || use === undefined)
    .filter(({ kty }) => kty === "RSA" || kty === "EC");

  for (const jwk of jwks) {
    try {
      const alg = resolveAlg(jwk);
      const key = await jwkToPem(jwk);
      results.push({
        publicKey: key,
        ...(typeof jwk.kid === "string" && jwk.kid
          ? { kid: jwk.kid }
          : undefined),
        ...(typeof jwk.alg === "string" && jwk.alg
          ? { alg: jwk.alg }
          : undefined),
      });
    } catch (err) {
      continue;
    }
  }

  return results;
}

module.exports = {
  retrieveSigningKeys,
};
