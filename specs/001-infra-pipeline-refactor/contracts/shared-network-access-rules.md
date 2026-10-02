# Contract: Shared Network Access Rules

## `deploy/bicep/modules/shared/networkAccessRules.bicep`

**Inputs**: none (or an optional `allowedIpRanges` array parameter if/when a consumer needs to override the default empty list — not required to ship an initial value beyond today's behavior).

**Output**

| Output | Type | Value |
|---|---|---|
| `defaultAction` | string | `'Deny'` |
| `bypass` | string | `'AzureServices'` |
| `allowedIpRanges` | array of string | `[]` today; extension point for future allow-listing |

This can be implemented either as a module with outputs (consumed via `module networkRules '...' = { ... }` and `networkRules.outputs.*`) or as an `@export()`-marked variable consumed via Bicep's `import { ... } from '...'` syntax — either satisfies FR-017 (one shared definition, multiple consumers); the choice is an implementation detail for `/speckit-tasks` to pin down, not a contract-level concern.

## Consumers

### Storage (`storageAccount.bicep`) and Key Vault (`keyvault.bicep`)

Both resource types accept a literal `networkAcls` object with `defaultAction` and `bypass` fields today. Each module consumes the shared output directly:

```text
networkAcls: {
  defaultAction: sharedNetworkRules.defaultAction
  bypass: sharedNetworkRules.bypass
}
```

(`allowedIpRanges`, if populated, maps to that property's own `ipRules`/`virtualNetworkRules`-equivalent list on each resource type — Storage's schema calls this `ipRules` within `networkAcls`; Key Vault's calls it `ipRules` within `networkAcls` too, so both can consume the shared list under the same target field name.)

### Cosmos DB (`cosmos.bicep`)

Cosmos has no `networkAcls` property. It maps the same shared fields into its own schema:

```text
publicNetworkAccess: sharedNetworkRules.defaultAction == 'Deny' ? 'Disabled' : 'Enabled'
ipRules: [for ip in sharedNetworkRules.allowedIpRanges: { ipAddressOrRange: ip }]
isVirtualNetworkFilterEnabled: true   // Cosmos-specific; stays local per FR-018, not part of the shared object
```

**Compatibility**: With `allowedIpRanges: []` (today's state), Storage and Key Vault produce the exact same `networkAcls` object as today; Cosmos continues to resolve to `publicNetworkAccess: 'Disabled'`, matching its current hardcoded value — no behavior change until the shared definition is actually edited (SC-007/SC-008).
