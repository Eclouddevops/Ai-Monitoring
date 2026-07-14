#!/bin/bash
# ============================================================
# One-time setup: Create S3 bucket and DynamoDB table for
# Terraform state backend
# Run this ONCE before terraform init
# ============================================================

set -e

AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="ai-monitoring-tfstate-${ACCOUNT_ID}"
DYNAMO_TABLE="ai-monitoring-tf-locks"

echo "============================================"
echo "  Terraform Backend Setup"
echo "  Account: ${ACCOUNT_ID}"
echo "  Region:  ${AWS_REGION}"
echo "============================================"
echo ""

# Create S3 bucket
echo "Creating S3 bucket: ${BUCKET_NAME}..."
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "  Bucket already exists. Skipping."
else
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${AWS_REGION}"

    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled

    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'

    # Block public access
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

    echo "  S3 bucket created successfully!"
fi

echo ""

# Create DynamoDB table for state locking
echo "Creating DynamoDB table: ${DYNAMO_TABLE}..."
if aws dynamodb describe-table --table-name "${DYNAMO_TABLE}" --region "${AWS_REGION}" 2>/dev/null; then
    echo "  Table already exists. Skipping."
else
    aws dynamodb create-table \
        --table-name "${DYNAMO_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}"

    echo "  Waiting for table to be active..."
    aws dynamodb wait table-exists \
        --table-name "${DYNAMO_TABLE}" \
        --region "${AWS_REGION}"

    echo "  DynamoDB table created successfully!"
fi

echo ""
echo "============================================"
echo "  Backend setup complete!"
echo ""
echo "  S3 Bucket:     ${BUCKET_NAME}"
echo "  DynamoDB:      ${DYNAMO_TABLE}"
echo "  Region:        ${AWS_REGION}"
echo ""
echo "  You can now run: terraform init"
echo "============================================"
