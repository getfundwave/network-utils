#!/bin/bash

PROFILE=$1
AWS_USERNAME=$2

if [ -z "$PROFILE" ] || [ -z "$AWS_USERNAME" ]; then
    echo "Usage [PROFILE] [AWS-USERNAME]"
    exit
fi

# Checking if all dependencies are installed, install if dependencies aren't present
if [ "$(uname -o)" = "GNU/Linux" ] && [ "$(dpkg -s jq 2>/dev/null | grep -c installed)" = 0 ]; then
    echo "jq not found... Installing jq"
    sudo apt-get install jq
else
    echo "Found jq"
fi

if [ "$(uname -o)" = "GNU/Linux" ] && [ "$(dpkg -s libsecret-tools 2>/dev/null | grep -c installed )" = 0 ]; then
    echo "libsecret-tools not found, installing libsecret-tools"
    sudo apt-get install libsecret-tools
else
    echo "found libsecret-tools"
fi
if [ "$(uname -o)" = "GNU/Linux" ] && [ "$(dpkg -s gnome-keyring 2>/dev/null | grep -c installed )" = 0 ]; then
    echo "gnome-keyring not found, installing gnome-keyring"
    sudo apt-get install gnome-keyring
else
    echo "Found gnome-keyring"
fi

# Making sure ~/.aws folder exists
test -d "$HOME/.aws" || mkdir "$HOME/.aws"
echo "[profile $PROFILE]" > "$HOME/.aws/config"

# store-credentials into secret-tool
bash ./store-credentials.sh

# Adding a credentials file in ~/.aws
cat ./config.sample > "$HOME/.aws/credentials"
sed -i "s/<profile>/$PROFILE/" "$HOME/.aws/credentials"

# Putting get-credentials and get-path in .local/bin folder
echo "Adding get-credentials and get-token to ~/.local/bin"
test -d "$HOME/.local/bin" || mkdir -p "$HOME/.local/bin"
cp ./get-credentials.sh "$HOME/.local/bin/get-credentials" || exit
chmod +x "$HOME/.local/bin/get-credentials"
cp ./get-token.sh "$HOME/.local/bin/get-token" || exit
chmod +x "$HOME/.local/bin/get-token"

# Getting mfa device configured by user on the console
DEVICE=$(aws iam list-virtual-mfa-devices --query "VirtualMFADevices[?User.UserName=='$AWS_USERNAME'].SerialNumber" --output text --profile "$PROFILE")

sed -i "s|DEVICE=.*|DEVICE=$DEVICE|" ~/.local/bin/get-token
sed -i "s/default/$PROFILE/" ~/.local/bin/get-token

# Adding .local/bin to user's PATH
echo "Adding ~/.local/bin to PATH"
if [ -f "$HOME/.bashrc" ]; then
    echo "export PATH=$HOME/.local/bin:$PATH" >> "$HOME/.bashrc"
    echo "export AWS_DEFAULT_PROFILE=$PROFILE" >> "$HOME/.bashrc"
fi

if [ -f "$HOME/.zshrc" ]; then
    echo "export PATH=$HOME/.local/bin:$PATH" >> "$HOME/.zshrc"
    echo "export AWS_DEFAULT_PROFILE=$PROFILE" >> "$HOME/.zshrc"
fi

# Final steps
sed -i "s/get-credentials creds$PROFILE notoken/get-credentials $PROFILE/" "$HOME/.aws/credentials"
echo "Open a new shell and run get-token [MFA-TOKEN]"
