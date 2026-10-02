# Phase 1 Data Model: Infrastructure Repository & Pipeline Refactor

This is an infrastructure-as-code feature: "entities" are configuration/deployment concepts realized as Bicep parameters, variables, module boundaries, and pipeline definitions rather than application data records. Each entity below corresponds to a Key Entity in the spec.

## Environment Variable File

Represents the per-environment configuration values consumed by a deployment run.

| Field | Type | Notes |
|---|---|---|
| `environment` | `'dev' \| 'prod'` | Matches the pipeline's environment parameter; selects this file by naming convention `deploy/variables/{environment}.bicepparam` |
| `location` | string | Azure region, currently `southeastasia` for both environments |
| `customDomain` | string | Differs per environment (e.g. `goatticket.kaidevops.online` for dev) |
| `keyVaultCertSecretUri` | string | Points at that environment's Key Vault; no cross-environment reuse |
| `ticketQrSigningKeyValue` | secure string | Sourced from an environment variable exported from the matching per-environment variable group (research decision 5), never literal in the file |

**Validation rules**: `environment` must be one of the two allowed values (enforced today by `@allowed(['dev','prod'])` on `main.bicep`'s parameter — unchanged by this refactor). A variable file must exist for every environment the pipeline template is instantiated for; a missing file is a deployment-time failure (`az deployment sub validate` fails to resolve the `--parameters` path), which satisfies FR-005's "fail clearly before any deployment step runs" when combined with the Quality Checks stage running Validate before any Deploy stage executes.

**Relationships**: Selected by exactly one pipeline stage-template instantiation (dev or prod); consumed by `main.bicep` at deployment time; does not reference or depend on other variable files.

## Pipeline Stage

Represents a named phase of the deployment pipeline.

| Field | Type | Notes |
|---|---|---|
| `name` | string | Internal stage identifier (YAML `stage:` key) |
| `displayName` | string | Plain-English, icon-free name shown in the Azure DevOps run UI (FR-012) |
| `dependsOn` | string or list | Enforces ordering: Quality Checks → Deploy Dev → Deploy Prod |
| `environment` (deploy stages only) | `'dev' \| 'prod'` | Template parameter driving variable-file and Azure DevOps Environment selection (FR-003) |
| outcome | pass/fail (+ per-step detail for Quality Checks) | Individual step results remain visible even when the stage overall fails (FR-011) |

**State transitions**: `Not started → Running → (Succeeded | Failed)`. For a deploy stage targeting `goat-prod`, `Running` additionally passes through an Azure DevOps Environment "Waiting for approval" state before any step executes, replacing the old `ConfirmProd` stage's `pool: server` wait.

**Relationships**: Quality Checks stage has no `environment` parameter (always checks against `dev`'s variable file as a pre-promotion smoke test, per research decision 3); Deploy Dev and Deploy Prod are two instantiations of the same stage template, differing only in their `environment` parameter value.

## Deployment Script

Represents one standalone file containing command logic for a specific deployment action.

| Field | Type | Notes |
|---|---|---|
| `path` | string | Under `deploy/script/`, one of `lint-bicep.sh`, `validate-deployment.sh`, `preview-changes.sh`, `deploy-environment.sh` |
| `arguments` | list of strings | At minimum the environment name; `deploy-environment.sh` and `preview-changes.sh`/`validate-deployment.sh` also need the resolved variable-file path |
| `environment variables consumed` | list | Secret values the calling pipeline step must export before invocation (e.g. `TICKET_QR_SIGNING_KEY_VALUE`), never passed as plain CLI arguments |

**Validation rules**: A script must be runnable and comprehensible standalone (Story 9's independent test) — no implicit dependency on pipeline-only context beyond documented arguments and environment variables.

**Relationships**: Each Quality Checks step and each Deploy stage step invokes exactly one script by path; no script invokes another script.

## Principal Access Entry

Represents one identity that should receive one role on Key Vault or Cosmos DB.

| Field | Type | Notes |
|---|---|---|
| `principalId` | string (GUID) | The identity's object ID (e.g. an App Service/Function App/App Gateway managed identity's `principalId`) |
| `roleDefinitionId` | string (GUID) | Built-in role ID (e.g. Key Vault Secrets User, Cosmos Data Reader) |
| `principalType` | string | e.g. `ServicePrincipal`; required by the Key Vault role-assignment resource schema |

**Validation rules**: Entries are deduplicated implicitly by the role-assignment resource's deterministic `guid(...)`-based name (unchanged pattern from today's individually-named resources) — two entries with the same `(scopeId, principalId, roleDefinitionId)` triple produce the same resource name and therefore the same assignment, not a duplicate.

**Relationships**: Lives in one of two arrays (`keyVaultPrincipals`, `cosmosPrincipals`) passed from the RBAC parent module into the matching child module; each array entry becomes exactly one role-assignment resource via the child module's `for` loop (FR-013/FR-014). Adding/removing an entry affects only that entry's resource instance (FR-016).

## Shared Network Access Rule

Represents the network-access policy intent common to Storage, Key Vault, and Cosmos DB.

| Field | Type | Notes |
|---|---|---|
| `defaultAction` | `'Deny' \| 'Allow'` | Today hardcoded to `Deny` identically in Storage and Key Vault |
| `bypass` | string | Today hardcoded to `AzureServices` identically in Storage and Key Vault |
| `allowedIpRanges` | list of strings (optional) | Not currently populated anywhere, but is the natural extension point this shared definition exists to make safe/easy to add consistently later |

**Validation rules**: This object expresses only the subset of settings meaningful to *all three* resource types (FR-017). A setting meaningful to only one resource type (for example Cosmos's `isVirtualNetworkFilterEnabled`) is defined locally in that resource's own module and must not be added here (FR-018).

**Relationships**: Storage and Key Vault consume this object directly as (or spread into) their `networkAcls` property. Cosmos DB maps `defaultAction`/`allowedIpRanges` into its own `publicNetworkAccess`/`ipRules` properties inside `cosmos.bicep`, since it has no `networkAcls` property to assign into.

## Deployment Slot

Represents an additional, independently addressable instance of App Service or the Function App.

| Field | Type | Notes |
|---|---|---|
| `parentResource` | `appService \| functionApp` | The site the slot belongs to |
| `slotName` | string | `staging`, fixed for this change |
| `inherits` | plan/tier | Same App Service Plan as the parent site (no separate plan provisioned) |

**Validation rules**: Must not disrupt the existing production slot when first created (edge case from spec). No app-setting divergence or traffic-routing configuration is introduced by this change — out of scope per spec Assumptions.

**Relationships**: One staging slot per site (App Service, Function App); no relationship to the RBAC or network-rule entities — slots do not currently receive their own distinct managed identity or role assignments in this change.
