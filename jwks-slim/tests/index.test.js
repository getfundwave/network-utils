const { JwksClient } = require("../src/JwksClient.js");
const { keys } = require("./data.js");

describe("JwksClient", () => {
  global.fetch = jest.fn(() =>
    Promise.resolve({
      json: () => Promise.resolve({ keys }),
    })
  );
  const jwksUri = "http://jwks-auth-server/.well-known/jwks.json";

  describe("Get Keys", () => {
    it("should return keys", async () => {
      const client = new JwksClient({
        jwksUri,
      });

      const keys = await client.getKeys();
      expect(keys).not.toBeNull();
      expect(keys).toHaveLength(2);
    });
  });

  describe("Get Signing Keys", () => {
    it("should return keys", async () => {
      const client = new JwksClient({
        jwksUri,
      });

      const keys = await client.getSigningKeys();
      expect(keys).not.toBeNull();
      expect(keys).toHaveLength(2);
    });
  });

  describe("Get Signing Key", () => {
    it("should give error if kid is not there in the keys", async () => {
      const client = new JwksClient({
        jwksUri,
      });

      try {
        const key = await client.getSigningKey("123");
      } catch (err) {
        expect(err.name).toBe("SigningKeyNotFoundError");
      }
    });
  });

  it("give error if kid is not defined", async () => {
    const client = new JwksClient({
      jwksUri,
    });

    try {
      const key = await client.getSigningKey(undefined);
    } catch (err) {
      expect(err.name).toBe("SigningKeyNotFoundError");
    }
  });

  it("should give the key", async () => {
    const client = new JwksClient({
      jwksUri,
    });

    const key = await client.getSigningKey(
      "RkI5MjI5OUY5ODc1N0Q4QzM0OUYzNkVGMTJDOUEzQkFCOTU3NjE2Rg"
    );

    expect(key).not.toBeNull();
    expect(key.kid).toMatch(
      "RkI5MjI5OUY5ODc1N0Q4QzM0OUYzNkVGMTJDOUEzQkFCOTU3NjE2Rg"
    );
    expect(key.publicKey).toMatch("BEGIN PUBLIC KEY");
  });
});
