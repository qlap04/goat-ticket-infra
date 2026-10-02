using '../bicep/main.bicep'

param environment = 'dev'
param location = 'southeastasia'
param customDomain = 'goatticket.kaidevops.online'
param keyVaultCertSecretUri = 'https://kv-goat-dev.vault.azure.net/secrets/cert-goatticket'
param ticketQrSigningKeyValue = readEnvironmentVariable('TICKET_QR_SIGNING_KEY_VALUE')
