#!/bin/bash
# Check if AWS_ACCOUNT_ALIAS is provided from the previous script
if [ -z "$AWS_ACCOUNT_ALIAS" ]; then
    # Prompt for AWS account name if not provided
    read -p "Enter the name of the AWS Account: " account_name
else
    account_name=$AWS_ACCOUNT_ALIAS
    echo "Using AWS Account Alias: $account_name"
fi

# Prompt for AWS account name for output file
#read -p "Enter the name of the AWS Account: " account_name

# Create folder
mkdir -p "$account_name"

cd "$account_name"

# Set the output CSV path
output_csv="aws-resources_${account_name}.csv"
echo "Region, Instance ID, AMI ID, OS Platform, OS Description" > "$output_csv"

# List of regions to iterate over
regions=(
  "us-east-1"       # N. Virginia
  "us-east-2"       # Ohio
  "us-west-1"       # N. California
  "us-west-2"       # Oregon
  "af-south-1"      # Africa (Cape Town)
  "ap-east-1"       # Asia Pacific (Hong Kong)
  "ap-south-1"      # Asia Pacific (Mumbai)
  "ap-south-2"      # Asia Pacific (Hyderabad)
  "ap-southeast-1"  # Asia Pacific (Singapore)
  "ap-southeast-2"  # Asia Pacific (Sydney)
  "ap-southeast-3"  # Asia Pacific (Jakarta)
  "ap-northeast-1"  # Asia Pacific (Tokyo)
  "ap-northeast-2"  # Asia Pacific (Seoul)
  "ap-northeast-3"  # Asia Pacific (Osaka)
  "ca-central-1"    # Canada (Central)
  "eu-central-1"    # Europe (Frankfurt)
  "eu-central-2"    # Europe (Zurich)
  "eu-west-1"       # Europe (Ireland)
  "eu-west-2"       # Europe (London)
  "eu-west-3"       # Europe (Paris)
  "eu-north-1"      # Europe (Stockholm)
  "eu-south-1"      # Europe (Milan)
  "eu-south-2"      # Europe (Spain)
  "me-south-1"      # Middle East (Bahrain)
  "me-central-1"    # Middle East (UAE)
  "sa-east-1"       # South America (São Paulo)
)

for region in "${regions[@]}"; do
    echo "Checking instances in region: $region"

    # Describe instances in the region and check if there are any instances
    instance_count=$(aws ec2 describe-instances --region "$region" --query "Reservations[*].Instances[*]" --output json 2>/dev/null | jq length)

    # Check if the describe-instances command was successful
    if [ $? -ne 0 ]; then
        echo "AuthFailure for region $region. Skipping..."
        echo "$region, AuthFailure, , , " >> "$output_csv"
        continue
    fi

    # If no instances are found
    if [ -z "$instance_count" ] || [ "$instance_count" -eq 0 ]; then
        echo "$region, No instances found, , , " >> "$output_csv"
        echo "No instances found in region $region"
        continue
    fi

    # Describe instances in the region and retrieve platform details
    aws ec2 describe-instances --region "$region" --output json > "${region}-instances.json"

    # Extract instance and AMI details, including platform information from describe-instances
    instances=$(jq -r '.Reservations[].Instances[] | [.InstanceId, .ImageId, (.PlatformDetails // .Platform // "Linux/Unix")] | @csv' "${region}-instances.json")

    # Loop through each instance to get detailed AMI information if needed
    while IFS=',' read -r instance_id ami_id platform; do
        # Trim any surrounding whitespace or quotes
        instance_id=$(echo "$instance_id" | tr -d '"')
        ami_id=$(echo "$ami_id" | tr -d '"')
        platform=$(echo "$platform" | tr -d '"')
        ami_description="No Description Available"  # Default value for AMI description

        # If platform is null or defaulted to "Linux/Unix", check the AMI details
        if [ "$platform" == "Linux/Unix" ] || [ "$platform" == "null" ]; then
            # Describe the AMI to get specific details
            ami_info=$(aws ec2 describe-images --image-ids "$ami_id" --region "$region" --query 'Images[0].{Name:Name, Description:Description}' --output json)

            # Use AMI name or description for more details
            ami_name=$(echo "$ami_info" | jq -r '.Name')
            ami_description=$(echo "$ami_info" | jq -r '.Description // "No Description Available"')

            # Check if the AMI description or name contains "Windows" to set the platform
            if [[ "$ami_description" == *"Windows"* ]] || [[ "$ami_name" == *"Windows"* ]]; then
                platform="Windows"
            else
                platform=$ami_name  # Use AMI name if it's not Windows
            fi
        fi

        # Append to the CSV, including the region, platform, and description
        echo "$region, $instance_id, $ami_id, $platform, $ami_description" >> "$output_csv"
    done <<< "$instances"

    echo "Instance data for region $region added to $output_csv"
done

# Clean up
rm *-instances.json

echo "OS version information saved to $output_csv"
