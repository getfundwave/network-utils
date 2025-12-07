WARNING: Only use read-only GITHUB token as GITHUB_READ_TOKEN. If a WRITE token is supplied, the container will cause malicious packages to be published.

# NPM Security Container

A Docker container designed to securely install npm dependencies and perform integrity checks on JavaScript files looking specifically for hashes that indicate infiltration by Sha1-Hulud malware that came out on Nov 24 2025. This container can be used as a precautionary step before `npm install`.

## Overview

This container performs the following operations:
1. Sets up authentication for GitHub packages (if `GITHUB_READ_TOKEN` is provided)
2. Runs `npm install` to install dependencies
3. Performs integrity checks on JavaScript files using SHA256 hashes that point to Sha1-Hulud malware files.
4. Returns appropriate exit codes based on the results

## Exit Codes

The container uses specific exit codes to indicate different states:

- **Exit Code 0**: ✅ **Success** - npm install succeeded and all integrity checks passed
- **Exit Code 1**: ❌ **Security Alert** - Integrity check failed, potentially malicious files detected
- **Exit Code 2**: 🔧 **Installation Error** - npm install failed

## Usage

### Basic Usage

```bash
docker pull ghcr.io/fundwave/npm-security:latest
docker run --rm -v $(pwd):/app ghcr.io/fundwave/npm-security:latest
```

### With GitHub Read Token (for private packages)

```bash
docker run --rm -v $(pwd):/app -e GITHUB_READ_TOKEN=your_github_readonly_token ghcr.io/fundwave/npm-security:latest
```

### CI/CD Integration

In your CI/CD pipeline, you can use the exit codes to determine the next steps:

```yaml
# Example GitHub Actions workflow
- name: Secure NPM Install
  run: |
    docker run --rm -v $(pwd):/app -e GITHUB_READ_TOKEN=${{ secrets.GITHUB_TOKEN }} ghcr.io/fundwave/npm-security:latest
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
      echo "Proceeding with build..."
    elif [ $EXIT_CODE -eq 1 ]; then
      echo "Security check failed - stopping deployment"
      exit 1
    elif [ $EXIT_CODE -eq 2 ]; then
      echo "Installation failed - check dependencies"
      exit 1
    fi
```

## Security Features

### Integrity Checking

The container checks for known malicious file hashes:
- Scans all `.js` files in the project
- Compares SHA256 hashes against a database of known threats
- Fails if any malicious patterns are detected

### Isolated Environment

- Runs in a containerized environment
- No access to host system beyond mounted volume
- Clean Alpine Linux base with minimal attack surface
- Use only a read-only GITHUB_TOKEN (with package read permissions only). Do not use tokens with write or publish permissions, as this may allow malicious packages to be published.

### Authentication

- Supports GitHub Package Registry authentication
- Tokens are handled securely through environment variables
- No credentials stored in the container image

## Development

### Building the Container

```bash
docker build -t npm-security .
```

### Testing

Test with a clean Node.js project:

```bash
# Create test project
mkdir test-project && cd test-project
npm init -y
echo '{}' > package.json

# Test the container
docker run --rm -v $(pwd):/app npm-security
echo "Exit code: $?"
```

## Environment Variables

- `GITHUB_READ_TOKEN`: GitHub Personal Access Token for accessing private packages in GitHub Package Registry

## Troubleshooting

### Common Issues

1. **Permission denied**: Ensure the mounted volume has correct permissions
2. **Network issues**: Check Docker network configuration for npm registry access
3. **Token issues**: Verify GitHub token has correct permissions for package registry

### Debug Mode

Run the container interactively to debug issues:

```bash
docker run -it --rm -v $(pwd):/app --entrypoint sh npm-security
```

## Contributing

When modifying the integrity check hashes, ensure you're adding legitimate threat signatures and document the source of the hash information.
