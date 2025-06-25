ACCOUNT_ID=$1
PROFILE=$2
POLICY_NAME=${3:-AWS_PRIVATE_CA_LAMBDA_UPDATE_POLICY}
ROLE_NAME=${4:-AWS_PRIVATE_CA_LAMBDA_UPDATE_ROLE}

[ ! -z $PROFILE ] && PROFILE="--profile=$PROFILE"

ROLE_ARN=$(aws iam list-roles --query "Roles[?RoleName=='$ROLE_NAME'].Arn" --output text $PROFILE)

if [ -n "$ROLE_ARN"  ] ; then
  echo "Role $ROLE_NAME already exists"
else
  ASSUME_ROLE_POLICY_DOC=$( sed "s/<account-id>/$ACCOUNT_ID/" policies/trust-relationship-policy.json )
  ROLE_ARN=$(aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document "$ASSUME_ROLE_POLICY_DOC" --output text $PROFILE --query 'Role.Arn')
  echo "Role created with arn: "
  echo $ROLE_ARN
fi

POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text $PROFILE)
if [ -n "$POLICY_ARN" ]; then
  echo "Policy $POLICY_NAME already exists"
else
  echo "Creating Policy"
  POLICY_DOC=$(sed -e "s/<account_id>/$ACCOUNT_ID/g" policies/lambda-update-policy.json)
  POLICY_ARN=$(aws iam create-policy --policy-name $POLICY_NAME --policy-document "$POLICY_DOC" $PROFILE --output text --query 'Policy.Arn' )
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn $POLICY_ARN $PROFILE
fi