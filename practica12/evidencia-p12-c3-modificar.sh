#!/usr/bin/env bash
set -euo pipefail
sed -i 's/Value: P12-IaC/Value: P12-IaC-Modificado/' p12-template.yaml
aws cloudformation deploy --stack-name p12-losrojos-iac --template-file p12-template.yaml \
  --parameter-overrides Environment=practica12 --no-fail-on-empty-changeset --region us-east-1
