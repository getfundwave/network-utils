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

Note: Once the lambda is deployed you will need to manually add an environment variable called `AWS_SECRETS_REGION` to store the region in which AWS secrets for privateCA reside.

## Prerequisites for usage

### Running via Docker

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
bash client/generate-certificate-curl.sh generateClientSSHCert <PRIVATE-CA-URL> client
```

#### For host certificates:

```bash
bash client/generate-certificate-curl.sh generateHostSSHCert <PRIVATE-CA-URL> host
```

**Note:**

1. Sudo privilege is required for generating host certificates as they need to write to system directories like `/etc/ssh`.
2. The `ENVIRONMENT` (host or client) parameter affects how AWS credentials are retrieved. See [Script Parameters](#script-parameters) for more details.

### Running via AWS CLI (Lambda)

The `generate-certificate-aws-cli.sh` script provides an alternative approach to generate certificates. This method uses AWS CLI to invoke a Lambda function rather than making direct HTTP requests.

#### Usage:

```bash
bash client/generate-certificate-aws-cli.sh <CA_ACTION> <ENVIRONMENT> <AWS-PROFILE> <USER-SSH-DIR> <SYSTEM-SSH-DIR> <LAMBDA-REGION> <CA-LAMBDA-FUNCTION-NAME> <AWS-STS-REGION>
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
      -v /home/$USER/.ssh:/root/.ssh \
      -v /etc/ssh:/etc/ssh \
      -v /etc/ssl/privateCA:/etc/ssl/privateCA \
      certificate-generator \
      generateHostSSHCert \
      https://<PRIVATE-CA-URL>/ \
      host \
      default \
      /root/.ssh
   ```

## Running as a cron job (optional)

Since certificates need to be renewed periodically, you can set up a cron job to automatically regenerate them.

Sample script:

```bash
#!/bin/bash

# Create the cron job entry
echo "* */1 * * * cd /path/to/private-ca && bash client/generate-certificate-curl.sh generateHostSSHCert https://<PRIVATE-CA-URL>/ host >> /home/cron.log 2>&1" > /tmp/root_crontab

# Load into root's crontab
crontab -u root /tmp/root_crontab

# Optionally start cron service (only if not already running)
systemctl start cron 2>/dev/null || systemctl start crond 2>/dev/null
```

## Script Parameters

Both `generate-certificate-curl.sh` and `generate-certificate-aws-cli.sh` accept several shared and some script-specific parameters.

| Parameter                 | Required | Description                                                                    | Used In Script(s)                 | Default Value      |
| ------------------------- | -------- | ------------------------------------------------------------------------------ | --------------------------------- | ------------------ |
| `CA_ACTION`               | Yes      | Action to perform: `generateClientSSHCert` or `generateHostSSHCert`            | Both                              | —                  |
| `CA_URL`                  | Yes      | URL of the Private CA                                                          | `generate-certificate-curl.sh`    | —                  |
| `ENVIRONMENT`             | No       | Machine environment: `"client"` (uses AWS CLI) or `"host"` (uses EC2 metadata) | Both                              | `client`           |
| `AWS_PROFILE`             | No       | AWS CLI profile name                                                           | Both                              | `default`          |
| `USER_SSH_DIR`            | No       | Path to user's SSH directory                                                   | Both                              | `/home/$USER/.ssh` |
| `USER_AWS_DIR`            | No       | Path to user's AWS directory                                                   | `generate-certificate-curl.sh`    | `/home/$USER/.aws` |
| `SYSTEM_SSH_DIR`          | No       | Path to system SSH directory                                                   | Both                              | `/etc/ssh`         |
| `AWS_STS_REGION`          | No       | AWS region to use for STS operations                                           | Both                              | `ap-southeast-1`   |
| `LAMBDA_REGION`           | No       | AWS region where the Lambda function is deployed                               | `generate-certificate-aws-cli.sh` | `us-west-2`        |
| `CA_LAMBDA_FUNCTION_NAME` | No       | Name of the Lambda function that performs certificate signing                  | `generate-certificate-aws-cli.sh` | `privateCA`        |

## Important Notes

- **Certificate Type**: Determined by the `CA_ACTION` parameter (`generateClientSSHCert` or `generateHostSSHCert`)
- **Permissions**: Host certificates require sudo privileges for system directory access

## Client Environment Limitations

**Important**: Client environments can only generate client certificates because they don't have a public IP address.

- **Host Certificate Requirements**: Host certificates require the public IP address as a hostname when issuing the certificate. Due to the absence of a public IP address, client environments cannot generate host certificates
- **Recommendation**: Use client environments exclusively for generating client certificates, and use host environments (such as EC2 instances with public IPs) for generating host certificates

## Directory Structure

- `deploy-server-on-lambda.sh`: Script to deploy the Lambda function and related AWS resources
- `update-server-on-lambda.sh`: Script to update the deployed Lambda function
- `client/`: Directory containing client-side tools
  - `generate-certificate-curl.sh`: Main script for certificate generation using curl
  - `generate-certificate-aws-cli.sh`: Alternative script using AWS CLI
  - `aws-auth-header.py`: Python helper for generating AWS authentication headers
  - `Dockerfile`: Docker container configuration
- `server/`: Directory containing server-side Lambda function code
