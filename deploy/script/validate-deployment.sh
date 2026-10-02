#!/usr/bin/env bash
set -euo pipefail

environment="$1"
variable_file="$2"

az deployment sub validate \
  --location southeastasia \
  --template-file deploy/bicep/main.bicep \
  --parameters "$variable_file" \
  --parameters ticketQrSigningKeyValue="$TICKET_QR_SIGNING_KEY_VALUE" \
  --parameters keyVaultCertSecretUri="$KEY_VAULT_CERT_SECRET_URI"
