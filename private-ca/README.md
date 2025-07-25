# Private Certificate Authority (CA) for SSH Certificates

This project provides a private Certificate Authority (CA) implementation for generating SSH certificates. It allows you to issue certificates for SSH hosts and users for secure communication.

## Deployment

Deploy the resources by running:

```bash
./deploy-server-on-lambda.sh
```

This creates the following resources on AWS:

- Secret to store the keys for signing certificates
- A role for the lambda function
- A policy to be attached to the role giving read access to created secret
- An openSSH layer to facilitate SSH operations
- The lambda function to act as a privateCA

## Prerequisites for usage

### Running via Docker (for host machines only)

- Docker

### Running directly

- Python 3
- Bash
- Dependencies: `curl`, `jq`, `ssh-keygen`, `base64`

### Running via AWS CLI (Lambda)

- AWS CLI
- Python 3
- Access to the Lambda function in the specified region

## Usage

### Running directly

#### For client certificates:

```bash
bash invoke-private-ca.sh generateClientSSHCert <PRIVATE-CA-URL> client
```

#### For host certificates:

```bash
bash invoke-private-ca.sh generateHostSSHCert <PRIVATE-CA-URL> host
```

#### For getting host CA public key:

```bash
bash invoke-private-ca.sh getHostCAPublicKey <PRIVATE-CA-URL> client
```

**Note:**

1. Sudo privilege is required for generating host certificates as they need to write to system directories like `/etc/ssh`.
2. The `ENVIRONMENT` (host or client) parameter affects how AWS credentials are retrieved. See [Script Parameters](#script-parameters) for more details.

### Running via AWS CLI (Lambda)

The `invoke-private-ca-aws-cli.sh` script provides an alternative approach to generate certificates. This method uses AWS CLI to invoke the Lambda function rather than making HTTP requests.

#### Usage:

```bash
bash invoke-private-ca-aws-cli.sh <CA_ACTION> <ENVIRONMENT> <USER-SSH-DIR> <SYSTEM-SSH-DIR> <CA-LAMBDA-FUNCTION-NAME> <LAMBDA-REGION> <AWS-STS-REGION> <AWS-EC2-REGION> <CERT-HALF-LIFE-SECONDS>
```

### Running via Docker

1. Build the Docker image:

   ```bash
   cd client
   docker build -t certificate-generator .
   ```

2. Run the Docker container with the required volume mounts and parameters:

   ```bash
   docker run --rm \
      -v $HOME/.ssh:/root/.ssh \
      -v /etc/ssh:/etc/ssh \
      certificate-generator \
      generateHostSSHCert \
      https://<PRIVATE-CA-URL>/ \
      host \
   ```

## Running as a cron job (optional)

Since certificates need to be renewed periodically, you can set up a cron job to automatically regenerate them.

Sample script:

```bash
#!/bin/bash

# Create the cron job entry
echo "* */1 * * * cd /path/to/private-ca/client && bash invoke-private-ca.sh generateHostSSHCert https://<PRIVATE-CA-URL>/ host >> /home/cron.log 2>&1" > /tmp/root_crontab

# Load into root's crontab
crontab -u root /tmp/root_crontab

# Optionally start cron service (only if not already running)
systemctl start cron 2>/dev/null || systemctl start crond 2>/dev/null
```

## Script Parameters

Both `invoke-private-ca.sh` and `invoke-private-ca-aws-cli.sh` accept several shared and some script-specific parameters.

| Parameter                 | Required | Description                                                                                | Used In Script(s)              | Default Value             |
| ------------------------- | -------- | ------------------------------------------------------------------------------------------ | ------------------------------ | ------------------------- |
| `CA_ACTION`               | Yes      | Action to perform: `generateClientSSHCert`, `generateHostSSHCert`, or `getHostCAPublicKey` | Both                           | —                         |
| `CA_URL`                  | Yes      | URL of the Private CA                                                                      | `invoke-private-ca.sh`         | —                         |
| `ENVIRONMENT`             | No       | Machine environment: `"client"` (uses AWS CLI) or `"host"` (uses EC2 metadata)             | Both                           | `client`                  |
| `USER_SSH_DIR`            | No       | Path to user's SSH directory                                                               | Both                           | `$HOME/.ssh`              |
| `USER_AWS_DIR`            | No       | Path to user's AWS directory                                                               | `invoke-private-ca.sh`         | `$HOME/.aws`              |
| `SYSTEM_SSH_DIR`          | No       | Path to system SSH directory                                                               | Both                           | `/etc/ssh`                |
| `AWS_STS_REGION`          | No       | AWS region to use for STS operations                                                       | Both                           | `eu-central-1`            |
| `LAMBDA_REGION`           | No       | AWS region where the Lambda function is deployed                                           | `invoke-private-ca-aws-cli.sh` | `eu-central-1`            |
| `CA_LAMBDA_FUNCTION_NAME` | No       | Name of the Lambda function that performs certificate signing                              | `invoke-private-ca-aws-cli.sh` | `privateCA`               |
| `AWS_EC2_REGION`          | No       | AWS region where the EC2 instance is deployed                                              | `invoke-private-ca-aws-cli.sh` | `eu-central-1`            |
| `CERT_HALF_LIFE_SECONDS`  | No       | Certificate half-life in seconds                                                           | Both                           | `259200 seconds (3 days)` |

## Important Notes

- **Certificate Type**: Determined by the `CA_ACTION` parameter (`generateClientSSHCert`, `generateHostSSHCert`, or `getHostCAPublicKey`)
- **Permissions**: Host certificates require sudo privileges for system directory access
- **Public Key Retrieval**: The `getHostCAPublicKey` action retrieves the Host CA's public key for host certificate verification

## Client Environment Limitations

**Important**: Client environments can only generate client certificates because they don't have a public IP address.

- **Host Certificate Requirements**: Host certificates require the public IP address as a hostname when issuing the certificate. Due to the absence of a public IP address, client environments cannot generate host certificates
- **Recommendation**: Use client environments exclusively for generating client certificates, and use host environments (such as EC2 instances with public IPs) for generating host certificates

## Directory Structure

- `deploy-server-on-lambda.sh`: Script to deploy the Lambda function and related AWS resources
- `update-server-on-lambda.sh`: Script to update the deployed Lambda function
- `client/`: Directory containing client-side tools
  - `invoke-private-ca.sh`: Main script for certificate generation using curl
  - `invoke-private-ca-aws-cli.sh`: Alternative script using AWS CLI
  - `aws-auth-header.py`: Python helper for generating AWS authentication headers
  - `Dockerfile`: Docker container configuration
- `server/`: Directory containing server-side Lambda function code

```

```
