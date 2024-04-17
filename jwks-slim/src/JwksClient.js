const { retrieveSigningKey } = require("./utils");
const { request, cacheSigningKey, callbackSupport } = require("./wrappers");
const { JwksError, SigningKeyNotFoundError } = require("./errors");

class JwksClient {
  constructor(options) {
    this.options = {
      cache: true,
      ...options,
    };

    // Initialize wrappers.
    if (this.options.cache) {
      this.getSigningKey = cacheSigningKey(this, options);
    }

    this.getSigningKey = callbackSupport(this, options);
  }

  #parseToken(token) {
    const tokenParts = token.split(".");
    if (tokenParts.length !== 3) {
      throw new Error("Invalid token format");
    }

    const header = JSON.parse(atob(tokenParts[0]));

    return { kid: header.kid };
  }

  async getKeys() {
    try {
      const res = await request({
        uri: this.options.jwksUri,
        headers: this.options.requestHeaders,
      });

      return res.keys;
    } catch (err) {
      console.log("Failure:", err.message);
      throw new JwksError(err.message);
    }
  }

  async getSigningKey(jwtToken) {
    try {
      const { kid } = this.#parseToken(jwtToken);
      if (kid === undefined || kid === null) {
        throw new SigningKeyNotFoundError("No KID specified");
      }

      const keys = await this.getKeys();

      if (!keys || !keys.length) {
        throw new SigningKeyNotFoundError(
          "The JWKS endpoint did not contain any keys"
        );
      }

      const jwk = keys.find((k) => k.kid === kid);

      if (!jwk) {
        throw new SigningKeyNotFoundError(`Unable to find key for kid ${kid}`);
      }

      const signingKey = await retrieveSigningKey(jwk);

      if (!signingKey) {
        throw new SigningKeyNotFoundError(
          `Unable to find signing key for kid ${kid}`
        );
      }

      return signingKey;
    } catch (err) {
      throw err;
    }
  }
}

module.exports = {
  JwksClient,
};
