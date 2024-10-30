#!/bin/bash

# Prompt for folder name
read -p "Enter the name of the folder to store CSVs and JSONs: " folder_name

# Create the directory if it doesn't exist
mkdir -p "$folder_name"

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

# Output CSV file path
output_csv="$folder_name/aws-resources_${folder_name}.csv"

# Write the CSV header
echo "Region,Service,ID/Name,Type,State/Runtime,Launch/Create/Modified Time,OS Type/Description,Private IP,Local Hostname,Backup Job/Plan Info,Monitoring" > "$output_csv"

for region in "${regions[@]}"; do
    echo "Running commands in region: $region"
 
    # EC2 Instances with Monitoring and Backup Data
    aws ec2 describe-instances --region "$region" --output json > "$folder_name/ec2-instances-$region.json"
    jq -r --arg region "$region" '.Reservations[].Instances[] | [$region, "EC2", .InstanceId, .InstanceType, .State.Name, .LaunchTime, (.Platform // "Linux/Unix"), .PrivateIpAddress, .PrivateDnsName, "N/A", (.Monitoring.State // "disabled")] | @csv' "$folder_name/ec2-instances-$region.json" >> "$output_csv"
    echo "EC2 instances data added to $output_csv"

    # EBS Volumes
    aws ec2 describe-volumes --region "$region" --output json > "$folder_name/ebs-volumes-$region.json"
    jq -r --arg region "$region" '.Volumes[] | [$region, "EBS", .VolumeId, .Size, .State, .CreateTime, "", "", "", "N/A", "N/A"] | @csv' "$folder_name/ebs-volumes-$region.json" >> "$output_csv"
    echo "EBS volumes data added to $output_csv"

    # ECS Clusters
    aws ecs list-clusters --region "$region" --output json > "$folder_name/ecs-clusters-$region.json"
    jq -r --arg region "$region" '.clusterArns[] | [$region, "ECS", ., "", "", "", "", "", "", "N/A", "N/A"] | @csv' "$folder_name/ecs-clusters-$region.json" >> "$output_csv"
    echo "ECS clusters data added to $output_csv"

    # EKS Clusters
    aws eks list-clusters --region "$region" --output json > "$folder_name/eks-clusters-$region.json"
    jq -r --arg region "$region" '.clusters[] | [$region, "EKS", ., "", "", "", "", "", "", "N/A", "N/A"] | @csv' "$folder_name/eks-clusters-$region.json" >> "$output_csv"
    echo "EKS clusters data added to $output_csv"

    # Fargate Tasks
    aws ecs list-tasks --launch-type FARGATE --region "$region" --output json > "$folder_name/fargate-tasks-$region.json"
    jq -r --arg region "$region" '.taskArns[] | [$region, "Fargate", ., "", "", "", "", "", "", "N/A", "N/A"] | @csv' "$folder_name/fargate-tasks-$region.json" >> "$output_csv"
    echo "Fargate tasks data added to $output_csv"

    # Lambda Functions
    aws lambda list-functions --region "$region" --output json > "$folder_name/lambda-functions-$region.json"
    jq -r --arg region "$region" '.Functions[] | [$region, "Lambda", .FunctionName, .Runtime, .LastModified, .MemorySize, "", "", "", "N/A", "N/A"] | @csv' "$folder_name/lambda-functions-$region.json" >> "$output_csv"
    echo "Lambda functions data added to $output_csv"

    # Backup Plans
    aws backup list-backup-plans --region "$region" --output json > "$folder_name/backup-plans-$region.json"
    jq -r --arg region "$region" '.BackupPlansList[] | [$region, "Backup Plan", .BackupPlanId, .BackupPlanName, .CreationDate, "", "", "", .BackupPlanId, "N/A"] | @csv' "$folder_name/backup-plans-$region.json" >> "$output_csv"
    echo "Backup plans data added to $output_csv"

    # Backup Jobs
    aws backup list-backup-jobs --region "$region" --output json > "$folder_name/backup-jobs-$region.json"
    jq -r --arg region "$region" '.BackupJobs[] | [$region, "Backup Job", .BackupJobId, .ResourceType, .CompletionDate, "", "", "", .BackupJobId, "N/A"] | @csv' "$folder_name/backup-jobs-$region.json" >> "$output_csv"
    echo "Backup jobs data added to $output_csv"
done

echo "All commands have been executed across all regions. Data saved to $output_csv."

echo "Remove JSON files"
rm $folder_name/*.json
