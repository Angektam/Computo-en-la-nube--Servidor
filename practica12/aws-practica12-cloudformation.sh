#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
STACK="p12-losrojos-iac"
TEMPLATE="${1:-p12-template.yaml}"

echo "== PRÁCTICA 12: INFRAESTRUCTURA COMO CÓDIGO =="
echo "Región: ${REGION} | Stack: ${STACK}"
aws cloudformation validate-template --template-body "file://${TEMPLATE}" --region "${REGION}"
aws cloudformation deploy --stack-name "${STACK}" --template-file "${TEMPLATE}" \
  --parameter-overrides Environment=practica12 --no-fail-on-empty-changeset --region "${REGION}"
echo "-- Segunda ejecución (idempotencia) --"
aws cloudformation deploy --stack-name "${STACK}" --template-file "${TEMPLATE}" \
  --parameter-overrides Environment=practica12 --no-fail-on-empty-changeset --region "${REGION}"
aws cloudformation describe-stacks --stack-name "${STACK}" \
  --query 'Stacks[0].{Status:StackStatus,Outputs:Outputs}' --output table --region "${REGION}"
