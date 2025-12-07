#!/bin/sh
set -e

# Known malicious SHA256 hashes (Sha1-Hulud malware signatures)
MALICIOUS_HASHES="a3894003ad1d293ba96d77881ccd2071446dc3f65f434669b49b3da92421901a|\
62ee164b9b306250c1172583f138c9614139264f889fa99614903c12755468d0|\
c723605455e8667a4c84327cf6b704bbdcb9b4ce3707ddddd927d32b8372ff77|\
2e44e8d8a8e906fd5bfbb37be08dfe2dcf1ce41bd4ba726987ab516446dfb4f1|\
fa7df9e9fc5390cc54e0086073fc9b3054087ffddf661bbc9f836b007fa25f20|\
d66343059793800e72ef17690ce26492dc854c8513905778630ff1ed4e7a81b8|\
981d3e2f5d7e26c93bd4b758ea722468900894fb2368db5f8399282e2414fe33"

# Exit codes
EXIT_SUCCESS=0
EXIT_SECURITY_ALERT=1
EXIT_INSTALLATION_ERROR=2

echo "Validating GitHub Token..."

if [ -f /app/package.json ] ; then cp /app/package.json ~/test/package.json; fi
if [ -f /app/package-lock.json ] ; then cp /app/package-lock.json ~/test/package-lock.json; fi
if [ -f /.env ] ; then echo ".env file found. Exiting"; exit $EXIT_INSTALLATION_ERROR; fi

# Skip validation if no token provided
if [ -z "${GITHUB_READ_TOKEN}" ]; then
    echo "No GITHUB_READ_TOKEN provided, skipping token validation."
else

    # Fetch GitHub API headers to validate token
    GITHUB_TOKEN_HEADERS=$(wget --server-response --spider \
        --header="Authorization: token ${GITHUB_READ_TOKEN}" \
        https://api.github.com 2>&1)

    if echo "${GITHUB_READ_TOKEN}" | grep -q "^ghs_"; then
        echo "GitHub Actions token detected - skipping read-only scope check."
    elif ! echo "$GITHUB_TOKEN_HEADERS" | grep -qi 'x-oauth-scopes:'; then
        echo "ERROR: Cannot determine token scope (may be fine-grained). Only read-only tokens are permitted!"
        exit $EXIT_INSTALLATION_ERROR
    elif echo "$GITHUB_TOKEN_HEADERS" | grep -i 'x-oauth-scopes:' | grep -qi 'write'; then
        echo "ERROR: Token has write access. Only read-only tokens are permitted!"
        exit $EXIT_INSTALLATION_ERROR
    else
        echo "Token validation passed - read-only access confirmed."
    fi
fi

echo "Running npm install..."
npm install || { echo "ERROR: npm install failed!"; exit $EXIT_INSTALLATION_ERROR; }

echo "Performing integrity checks on JavaScript files..."
SUSPICIOUS_FILES=$(find . -type f -name "*.js" -exec sha256sum {} \; | grep -iE "$MALICIOUS_HASHES" || true)

# Exit if malicious files found
[ -n "$SUSPICIOUS_FILES" ] && { 
    echo "SECURITY ALERT: Malicious files detected!"
    echo "$SUSPICIOUS_FILES"
    exit $EXIT_SECURITY_ALERT
}

exit $EXIT_SUCCESS
