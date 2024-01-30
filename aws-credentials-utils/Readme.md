aws-credentials-utils lets you store your AWS ACCESS_KEY_ID and SECRET_ACCESS_KEY in a secure storage depending on your OS. 

## Prerequisites
#### Linux:
1. gnome-keyring
2. libsecret-tools
3. jq

#### Mac:
1. jq

## Installation
1. Run the setup.sh script
```
bash setup.sh [PROFILE] [AWS-USERNAME]
```

## Usage
- After running the setup script, open a new shell and run
```
get-token [MFA-TOKEN]
``
This generates temporary credentials that are valid for 8 hours and stores it in a secured location. You can now use your AWS CLI. To refresh your token run the above command again.
