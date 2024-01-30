#!/bin/bash

PROFILE=$1
AWS_USERNAME=$2

if [ "$(dpkg -l jq | grep -c 'jq')" = 1 ]; then
    echo "jq not found... Installing jq"
    sudo apt-get install jq
else
    echo "Found jq"
fi

if [ "$(dpkg -l libsecret-tools | grep -c 'libsecret-tools')" = 1 ]; then
    echo "libsecret-tools not found, installing libsecret-tools"
    sudo apt-get install libsecret-tools
else
    echo "found libsecret-tools"
fi
if [ "$(dpkg -l gnome-keyring | grep -c 'gnome-keyring')" = 1 ]; then
    echo "gnome-keyring not found, installing gnome-keyring"
    sudo apt-get install gnome-keyring
else
    echo "Found gnome-keyring"
fi

# store-credentials
bash ./store-credentials.sh

DEVICE=$(aws iam list-virtual-mfa-devices --query "VirtualMFADevices[?User.UserName=='$AWS_USERNAME'].SerialNumber" --output text)

sed -i "s/DEVICE=.*/DEVICE=$DEVICE/" ./get-token.sh
sed -i "s/default/$PROFILE" ./get-token.sh

# Finale
echo "Adding get-credentials and get-token to ~/.local/bin"
cp ./get-credentials.sh "$HOME/.local/bin/get-credentials" || exit
chmod +x "$HOME/.local/bin/get-credentials"
cp ./get-token.sh "$HOME/.local/bin/get-token" || exit
chmod +x "$HOME/.local/bin/get-token"

echo "Adding ~/.local/bin to PATH"
if [ -f "$HOME/.bashrc" ]; then
    echo "export PATH=$HOME/.local/bin:$PATH" | tee -a "$HOME/.bashrc"
fi

if [ -f "$HOME/.zshrc" ]; then
    echo "export PATH=$HOME/.local/bin:$PATH" | tee -a "$HOME/.zshrc"
fi

echo "Open a new shell and run get-token [MFA-TOKEN]"
