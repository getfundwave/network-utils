const { retrieveSigningKeys } = require("./utils");
const { request, cacheSigningKey, callbackSupport } = require("./wrappers");
const JwksError = require("./errors/JwksError");
const SigningKeyNotFoundError = require("./errors/SigningKeyNotFoundError");

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

  async getSigningKeys() {
    const keys = await this.getKeys();

    if (!keys || !keys.length) {
      throw new JwksError("The JWKS endpoint did not contain any keys");
    }

    const signingKeys = await retrieveSigningKeys(keys);

    if (!signingKeys.length) {
      throw new JwksError("The JWKS endpoint did not contain any signing keys");
    }

    return signingKeys;
  }

  async getSigningKey(kid) {
    const keys = await this.getSigningKeys();

    if (kid === undefined || kid === null) {
      throw new SigningKeyNotFoundError("No KID specified");
    }

    const key = keys.find((k) => k.kid === kid);
    if (key) {
      return key;
    } else {
      throw new SigningKeyNotFoundError(
        `Unable to find a signing key that matches '${kid}'`
      );
    }
  }
}

module.exports = {
  JwksClient,
};
