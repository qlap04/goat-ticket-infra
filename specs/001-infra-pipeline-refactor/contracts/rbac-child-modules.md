# Contract: RBAC Child Modules (Key Vault / Cosmos Role Assignments)

This project has no runtime API; its "contracts" are the Bicep module parameter/output interfaces other modules and the pipeline rely on. This contract covers the two new child modules introduced by research decision 6.

## `keyVaultRoleAssignments.bicep`

**Inputs**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `keyVaultId` | string | yes | Resource ID of the target Key Vault |
| `principals` | array of `{ principalId: string, roleDefinitionId: string, principalType: string }` | yes | One entry per identity to grant a role on this Key Vault |

**Behavior**

- Declares an `existing` reference to the Key Vault by ID (same pattern as today's `rbac.bicep`).
- Declares exactly one `Microsoft.Authorization/roleAssignments` resource using a Bicep `for` expression over `principals`, scoped to the Key Vault.
- Each generated assignment's name is deterministic: `guid(keyVaultId, principals[i].principalId, principals[i].roleDefinitionId)` — identical in shape to today's per-principal `guid(...)` calls, so re-running with an unchanged `principals` array produces no diff.

**Outputs**: none required (role assignments are terminal resources; nothing downstream consumes their resource IDs today).

**Compatibility**: Given a `principals` array containing exactly the entries that correspond to today's two individually-named Key Vault assignments (`appToKeyVault`, `agwToKeyVault`), the resulting deployment produces the same two role assignments with the same names — satisfies FR-020 ("no unintended access changes").

## `cosmosRoleAssignments.bicep`

**Inputs**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `cosmosAccountId` | string | yes | Resource ID of the target Cosmos account |
| `principals` | array of `{ principalId: string, roleDefinitionId: string }` | yes | One entry per identity to grant a Cosmos SQL role on this account (Cosmos role assignments have no `principalType` field, matching today's `sqlRoleAssignments` resource schema) |

**Behavior**

- Declares an `existing` reference to the Cosmos account by ID.
- Declares exactly one `Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments` resource using a Bicep `for` expression over `principals`, parented to the Cosmos account.
- Each generated assignment's name is deterministic: `guid(cosmosAccountId, principals[i].principalId, principals[i].roleDefinitionId)`, matching today's `appToCosmosReader` / `funcToCosmosReader` naming pattern.

**Outputs**: none required.

**Compatibility**: Given a `principals` array containing the entries corresponding to today's `appToCosmosReader` and `funcToCosmosReader` assignments, produces the same two assignments with the same names.

## `rbac.bicep` (parent)

**Inputs**: Unchanged parameter surface from today (`appServicePrincipalId`, `functionAppPrincipalId`, `agwIdentityPrincipalId`, `sqlServerPrincipalId`, `keyVaultId`, `cosmosAccountId`, `runtimeStorageAccountId`, `businessStorageAccountId`) — `main.bicep`'s call site does not need to change.

**Behavior**:

- Builds the `keyVaultPrincipals` and `cosmosPrincipals` arrays internally from its own input parameters (the array construction is the parent's responsibility, not pushed onto `main.bicep`), then invokes the two child modules above.
- Keeps today's four Storage/SQL role-assignment resources (`funcToRuntimeStorage`, `funcToBusinessBlob`, `funcToBusinessQueue`, `sqlToRuntimeStorage`) declared directly, unchanged (research decision 6 — out of scope for array/loop conversion).

**Outputs**: none required (unchanged from today).
