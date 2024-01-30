aws-credentials-utils lets you store your AWS ACCESS_KEY_ID and SECRET_ACCESS_KEY in a secure storage depending on your OS. 

## Prerequisites
#### Linux:
1. gnome-keyring
2. libsecret-tools
3. jq

#### Mac:
None

## Installation (Ubuntu)
1. Run the setup.sh script
```
bash setup.sh [PROFILE] [AWS-USERNAME]
```
## WORKING 
1. Edit ~/.aws/credentials
   1. Copy the contents of config.sample and replace profile with the AWS profile name you want to set.
2. Store the credentials. 
   In case of ubuntu follow these steps:
    1. Install gnome-keyring to store secrets.
       ```
       sudo apt-get install -y gnome-keyring
       ```
    2. Install libsecrets-tool to store secrets in gnome-keyring.
       ```
       sudo apt install libsecret-tools
       ```
    3. Install jq
       ```
       sudo apt install jq
       ```
    3. Execute
        ```
        bash store-credentials.sh
        ```
    4. You will get a prompt. Enter the values.
    
    For mac:
    1. Run
        ```
        bash store-credentials.sh
        ```

3. To get the credentials.
    1. Make get-credentials executable. Eg.
        ```
        chmod +x get-credentials.sh
        ```
    2. Path for this file has already been configured in step 1.
    3. Try running the following command to check if the credentials have been stored properly
        ```
        bash ./get-credentials.sh creds<profile> notoken
        ```
## Steps to configure use MFA script
1. In the get-token.sh script, we will need the MFA token and the arn of the mfa device that was registered for MFA.
   The MFA device ARN can be obtained by running the command:
   ```
   aws iam list-virtual-mfa-devices --query "VirtualMFADevices[?User.UserName==AWS_USERNAME].SerialNumber"
   ```
2. Run the get-token.sh script as follows:
    ```
        bash get-token.sh [TOKEN] [MFA-DEVICE-ARN] [AWS_PROFILE]
    ```
