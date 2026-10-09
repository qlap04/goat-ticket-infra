// deploy/bicep/modules/shared/naming.bicep
// Single source for the names of resources whose name is a globally unique DNS label.
// Exported functions (not a module) so consuming files can build names at compile time and so the
// convention is stated exactly once — the same reason networkAccessRules.bicep is an @export() const.
//
// These five names live in a global namespace (*.vault.azure.net, *.database.windows.net,
// *.documents.azure.com, *.azurewebsites.net), so a name already in use by any other subscription
// cannot be taken. `nameSuffix` exists to move the whole set to a free name without editing five
// modules: it comes from the .bicepparam of each environment. Each function inserts the separator
// itself, so the parameter carries the suffix alone ('cr7') and an empty value leaves the base name
// untouched ('kv-goat-dev', not 'kv-goat-dev-').
//
// Resources whose names are only unique inside the resource group (plans, NSGs, route tables,
// private endpoints, the firewall and the gateway) keep building their own names locally.

@export()
func keyVaultName(environment string, nameSuffix string) string =>
  'kv-goat-${environment}${empty(nameSuffix) ? '' : '-${nameSuffix}'}'

@export()
func sqlServerName(environment string, nameSuffix string) string =>
  'sql-goat-${environment}${empty(nameSuffix) ? '' : '-${nameSuffix}'}'

@export()
func cosmosAccountName(environment string, nameSuffix string) string =>
  'cosmos-goat-${environment}${empty(nameSuffix) ? '' : '-${nameSuffix}'}'

@export()
func appServiceName(environment string, nameSuffix string) string =>
  'app-goat-api-${environment}${empty(nameSuffix) ? '' : '-${nameSuffix}'}'

@export()
func functionAppName(environment string, nameSuffix string) string =>
  'func-goat-worker-${environment}${empty(nameSuffix) ? '' : '-${nameSuffix}'}'

// Storage account names allow only lowercase letters and digits, no dashes, and at most 24
// characters. They are globally unique too, which is why they also take nameSuffix: a name already
// held elsewhere is moved by changing that one value, the same way as the five above.
@export()
func runtimeStorageAccountName(environment string, nameSuffix string) string =>
  toLower('stgrt${environment}${nameSuffix}')

@export()
func businessStorageAccountName(environment string, nameSuffix string) string =>
  toLower('stgbiz${environment}${nameSuffix}')

// App Configuration store names live in the *.azconfig.io namespace, so they are globally unique
// too. Between 5 and 50 characters, letters, digits and hyphens.
@export()
func appConfigurationName(environment string, nameSuffix string) string =>
  'appcs-goat-${environment}${empty(nameSuffix) ? '' : '-${nameSuffix}'}'
