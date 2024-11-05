#!/bin/bash

# Prompt for SSO username, password, session time, and script to run
read -p "Enter SSO Username: " SSO_USERNAME
read -s -p "Enter SSO Password: " SSO_PASSWORD
echo
read -p "Enter session time (0, 1, 2): " SESSION_TIME
read -p "Enter the script to run (including path if not in the current directory): " RESOURCE_SCRIPT

# Set the AWS profile
export AWS_PROFILE=saml

# List of accounts to log into (0-50)
accounts=$(seq 0 50)

# Loop through each account
for account in $accounts; do
    echo "Logging in to AWS Account: $account"

    expect <<EOF
    spawn cyberpeacock_login --user $SSO_USERNAME
    expect "SSO password:"
    send "$SSO_PASSWORD\r"

    # Expect DUO push confirmation
    expect "Duo Push"
    send "\r"

    # Select AWS Account
    expect "AWS Account to logon: 0-60"
    send "$account\r"

    # Select session duration (0,1,2)
    expect "time/session: 0,1,2"
    send "$SESSION_TIME\r"

    # Wait for login to complete
    expect eof
EOF

    # Sleep outside of the expect block to give extra time for DUO push acceptance
    sleep 20

    # Get the current AWS account alias and ID
    retries=3
    for ((i=1; i<=retries; i++)); do
        AWS_ACCOUNT_ALIAS=$(AWS_PROFILE=saml aws sts get-caller-identity --query "Account" --output text 2>/dev/null)

        if [ $? -eq 0 ]; then
            # Successfully retrieved the account alias
            break
        elif [ $i -eq $retries ]; then
            echo "Failed to retrieve AWS account alias for account $account after $i attempts. Skipping..."
            continue 2  # Skip to the next account in the loop
        fi

        echo "Retrying to get AWS account alias (attempt $i)..."
        sleep 5  # Wait before retrying
    done

    # Export the AWS account alias to make it available for subsequent scripts
    export AWS_ACCOUNT_ALIAS

    # Echo the current AWS account ID and alias
    echo "Current AWS Account ID: $AWS_ACCOUNT_ALIAS"

    # After login, run the resource-gathering script
    echo "Running data collection for AWS Account ID: $AWS_ACCOUNT_ALIAS using script: $RESOURCE_SCRIPT"

    # Run the specified resource-gathering script
    bash "$RESOURCE_SCRIPT"

    echo "Data collection complete for AWS Account ID: $AWS_ACCOUNT_ALIAS"
done

# Unset sensitive information for security purposes
unset SSO_USERNAME
unset SSO_PASSWORD
unset SESSION_TIME
unset AWS_PROFILE

echo "Script completed and sensitive information has been unset."
