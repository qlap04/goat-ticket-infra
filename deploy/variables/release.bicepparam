using '../bicep/main.bicep'

param environment = 'dev'

param location = 'southeastasia'

param customDomain = 'goatticket.kaidevops.online'

param nameSuffix = 'cr7'

param keyVaultCertSecretUri = 'https://kv-goat-dev-cr7.vault.azure.net/secrets/cert-goatticket'

param wafMode = 'Detection'

// Environment specific object, supplied by the pipeline as ABC_JSON. Falls back to an empty object for local builds.
param abc = json(readEnvironmentVariable('ABC_JSON', '{}'))

// all deploys both resource groups; app skips rg-network. Supplied by the pipeline as DEPLOY_SCOPE.
param deployScope = readEnvironmentVariable('DEPLOY_SCOPE', 'all')
