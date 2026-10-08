using '../bicep/main.bicep'

param environment = 'dev'

param location = 'southeastasia'

param customDomain = 'goatticket.kaidevops.online'

param nameSuffix = 'cr7'

param keyVaultCertSecretUri = 'https://kv-goat-dev-cr7.vault.azure.net/secrets/cert-goatticket'

param wafMode = 'Detection'
