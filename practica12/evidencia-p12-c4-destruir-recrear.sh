#!/usr/bin/env bash
set -euo pipefail
T0=$(date +%s)
aws cloudformation delete-stack --stack-name p12-losrojos-iac --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name p12-losrojos-iac --region us-east-1
T1=$(date +%s)
echo "DESTROY_SECONDS=$((T1-T0))"
T2=$(date +%s)
aws cloudformation create-stack --stack-name p12-losrojos-iac --template-body file://p12-template.yaml \
  --parameters ParameterKey=Environment,ParameterValue=practica12 --region us-east-1
aws cloudformation wait stack-create-complete --stack-name p12-losrojos-iac --region us-east-1
T3=$(date +%s)
echo "RECREATE_SECONDS=$((T3-T2))"
