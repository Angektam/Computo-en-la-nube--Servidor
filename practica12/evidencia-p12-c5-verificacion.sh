#!/usr/bin/env bash
set -euo pipefail
B=$(aws cloudformation describe-stacks --stack-name p12-losrojos-iac \
  --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text --region us-east-1)
echo "BUCKET=${B}"
aws s3api get-bucket-tagging --bucket "${B}" --output table --region us-east-1
aws cloudformation describe-stacks --stack-name p12-losrojos-iac \
  --query 'Stacks[0].StackStatus' --output text --region us-east-1
