#!/usr/bin/env bash
set -euo pipefail
aws cloudformation create-change-set --stack-name p12-losrojos-iac --change-set-name p12-preview \
  --change-set-type UPDATE --template-body file://p12-template.yaml \
  --parameters ParameterKey=Environment,ParameterValue=practica12 --region us-east-1
aws cloudformation describe-change-set --stack-name p12-losrojos-iac --change-set-name p12-preview \
  --query 'Changes[].ResourceChange.{Action:Action,LogicalId:LogicalResourceId,Type:ResourceType,Replacement:Replacement}' \
  --output table --region us-east-1
