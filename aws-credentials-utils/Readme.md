aws-credentials-utils lets you store your AWS ACCESS_KEY_ID and SECRET_ACCESS_KEY in a secure storage depending on your OS. 

## Prerequisites
#### Linux:
1. gnome-keyring
2. libsecret-tools

## Steps
1. Edit ~/.aws/config
   1. Copy the contents of config.sample and replace profile with the AWS profile name you want to set.
   2. Replace the location of your get-credentials file.
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
    3. Execute
        ```
        sh store-credentials.sh
        ```
    4. You will get a prompt. Enter the values.
    
    For mac:
    1. Run
        ```
        sh store-credentials.sh
        ```

3. To get the credentials.
    1. Make get-credentials executable. Eg.
        ```
        chmod +x get-credentials.sh
        ```
    2. Path for this file has already been configured in step 1.
    3. Run any aws command with the profile you have set. Eg:
        ```
        aws s3 ls --profile <profile>
        ```