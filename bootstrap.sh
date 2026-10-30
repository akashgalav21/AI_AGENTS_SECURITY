#!/bin/bash
set -e

REGION=${1:-ap-southeast-2}
BUCKET="research-agent-tfstate-161877660149"
TABLE="research-agent-tf-locks"

echo "Creating S3 bucket: $BUCKET in region: $REGION"

# us-east-1 is the only region that must not send a LocationConstraint
if [ "$REGION" = "us-east-1" ]; then
  LOCATION_ARGS=()
else
  LOCATION_ARGS=(--create-bucket-configuration "LocationConstraint=$REGION")
fi

if CREATE_ERR=$(aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    "${LOCATION_ARGS[@]}" 2>&1); then
  echo "Bucket created."
elif echo "$CREATE_ERR" | grep -q "BucketAlreadyOwnedByYou"; then
  echo "Bucket already exists and is owned by you, continuing."
else
  echo "Could not create bucket:" >&2
  echo "$CREATE_ERR" >&2
  exit 1
fi

echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --versioning-configuration Status=Enabled

echo "Blocking public access on S3 bucket..."
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Enabling server-side encryption on S3 bucket..."
aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# echo "Creating DynamoDB table for Terraform state locking: $TABLE"
# aws dynamodb create-table \
#   --table-name "$TABLE" \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region "$REGION" 2>/dev/null && echo "DynamoDB table created." || echo "DynamoDB table already exists, continuing."

echo ""
echo "Bootstrap complete."
echo "  S3 bucket  : $BUCKET (versioned, encrypted, private)"
# echo "  DynamoDB   : $TABLE (state locking)"
echo ""
echo "Next step: cd terraform && terraform init && terraform apply"
