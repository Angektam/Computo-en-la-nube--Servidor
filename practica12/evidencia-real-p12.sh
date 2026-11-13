#!/usr/bin/env bash
set -eo pipefail

# Ejecutar desde AWS CloudShell. Las salidas son datos reales de la cuenta.
REGION="$AWS_REGION"
STACK="p12-losrojos-iac"
TEMPLATE="p12-template.yaml"
ENVIRONMENT="practica12"

header() {
  printf '\n===== %s =====\n' "$1"
  printf 'UTC: '; date -u '+%Y-%m-%dT%H:%M:%SZ'
  printf 'Cuenta y usuario reales:\n'
  aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table
  printf 'Region real: %s\n' "$REGION"
}

header 'C1 - template y previsualizacion'
printf 'Archivo: %s\n' "$TEMPLATE"
aws cloudformation validate-template --template-body "file://$TEMPLATE" --region "$REGION" --output table
aws cloudformation create-change-set --stack-name "$STACK" --change-set-name "p12-preview-$(date +%s)" \
  --change-set-type UPDATE --template-body "file://$TEMPLATE" \
  --parameters "ParameterKey=Environment,ParameterValue=$ENVIRONMENT" --region "$REGION" --output json

header 'C2 - aplicacion e idempotencia'
aws cloudformation deploy --stack-name "$STACK" --template-file "$TEMPLATE" \
  --parameter-overrides "Environment=$ENVIRONMENT" --no-fail-on-empty-changeset --region "$REGION"
aws cloudformation deploy --stack-name "$STACK" --template-file "$TEMPLATE" \
  --parameter-overrides "Environment=$ENVIRONMENT" --no-fail-on-empty-changeset --region "$REGION"

header 'C3 - stack y bucket reales'
aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query 'Stacks[0].{StackStatus:StackStatus,StackId:StackId,Outputs:Outputs}' --output table
BUCKET="$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text)"
printf 'Bucket real: %s\n' "$BUCKET"
aws s3api head-bucket --bucket "$BUCKET" --region "$REGION"
aws s3api get-bucket-versioning --bucket "$BUCKET" --region "$REGION" --output table
aws s3api get-public-access-block --bucket "$BUCKET" --region "$REGION" --output table
aws s3api get-bucket-encryption --bucket "$BUCKET" --region "$REGION" --output table

printf '\n===== Captura requerida en consola S3 =====\n'
printf 'Abrir S3 > Buckets > %s > Properties. Capturar el encabezado de AWS.\n' "$BUCKET"

header 'C4 - destruccion y recreacion'
read -r -p 'Escribe DESTRUIR para continuar: ' CONFIRM
[ "$CONFIRM" = 'DESTRUIR' ]
START_DELETE=$(date +%s)
aws cloudformation delete-stack --stack-name "$STACK" --region "$REGION"
aws cloudformation wait stack-delete-complete --stack-name "$STACK" --region "$REGION"
END_DELETE=$(date +%s)
printf 'DELETE_SECONDS=%s\n' "$((END_DELETE-START_DELETE))"
START_CREATE=$(date +%s)
aws cloudformation create-stack --stack-name "$STACK" --template-body "file://$TEMPLATE" \
  --parameters "ParameterKey=Environment,ParameterValue=$ENVIRONMENT" --region "$REGION"
aws cloudformation wait stack-create-complete --stack-name "$STACK" --region "$REGION"
END_CREATE=$(date +%s)
printf 'CREATE_SECONDS=%s\n' "$((END_CREATE-START_CREATE))"
aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query 'Stacks[0].{StackStatus:StackStatus,StackId:StackId}' --output table

header 'C5 - comprobacion final'
aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query 'Stacks[0].{StackStatus:StackStatus,Outputs:Outputs}' --output table
