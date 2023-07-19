
#!/bin/bash

profile=${1:-'internal'}

access_key=$(secret-tool lookup provider aws profile $profile | base64 -d)

# echo $access_key
access_key_id=$(echo "$access_key" | grep -o 'AccessKeyId: [^,]*' | awk -F': ' '{ print $2 }')
secret_access_key=$(echo "$access_key" | grep -o 'SecretAccessKey: [^ }]*' | awk -F': ' '{ print $2 }')

# Output the formatted JSON structure
cat <<EOF
{
  "Version": 1,
  "AccessKeyId": "$access_key_id",
  "SecretAccessKey": "$secret_access_key"
}
EOF