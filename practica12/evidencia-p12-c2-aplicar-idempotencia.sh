#!/usr/bin/env bash
set -euo pipefail
aws cloudformation deploy --stack-name p12-losrojos-iac --template-file p12-template.yaml \
  --parameter-overrides Environment=practica12 --no-fail-on-empty-changeset --region us-east-1
